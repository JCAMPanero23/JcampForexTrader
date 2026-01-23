using System;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using JcampForexTrader.Backtest;

namespace JcampForexTrader.Services
{
    public class BacktestApiClient
    {
        private readonly HttpClient _httpClient;
        private readonly string _baseUrl;

        public BacktestApiClient(string baseUrl = "http://localhost:8001")
        {
            _baseUrl = baseUrl;
            _httpClient = new HttpClient
            {
                BaseAddress = new Uri(_baseUrl),
                Timeout = TimeSpan.FromMinutes(10) // Long timeout for backtests
            };
        }

        /// <summary>
        /// Check if the API server is running and healthy
        /// </summary>
        public async Task<HealthResponse> CheckHealthAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync("/api/v1/health");
                response.EnsureSuccessStatusCode();

                var content = await response.Content.ReadAsStringAsync();
                return JsonConvert.DeserializeObject<HealthResponse>(content);
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to connect to API server at {_baseUrl}: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Get system information from the API
        /// </summary>
        public async Task<InfoResponse> GetSystemInfoAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync("/api/v1/info");
                response.EnsureSuccessStatusCode();

                var content = await response.Content.ReadAsStringAsync();
                return JsonConvert.DeserializeObject<InfoResponse>(content);
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to get system info: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Submit a new backtest request
        /// </summary>
        public async Task<BacktestResponse> SubmitBacktestAsync(BacktestRequest request)
        {
            try
            {
                var json = JsonConvert.SerializeObject(request);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync("/api/v1/backtest/run", content);
                response.EnsureSuccessStatusCode();

                var responseContent = await response.Content.ReadAsStringAsync();
                return JsonConvert.DeserializeObject<BacktestResponse>(responseContent);
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to submit backtest: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Get the status of a running backtest
        /// </summary>
        public async Task<BacktestStatus> GetBacktestStatusAsync(string taskId)
        {
            try
            {
                var response = await _httpClient.GetAsync($"/api/v1/backtest/{taskId}/status");
                response.EnsureSuccessStatusCode();

                var content = await response.Content.ReadAsStringAsync();
                return JsonConvert.DeserializeObject<BacktestStatus>(content);
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to get backtest status: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Get the complete results of a finished backtest
        /// </summary>
        public async Task<BacktestResults> GetBacktestResultsAsync(string taskId)
        {
            try
            {
                var response = await _httpClient.GetAsync($"/api/v1/backtest/{taskId}/results");
                response.EnsureSuccessStatusCode();

                var content = await response.Content.ReadAsStringAsync();
                return JsonConvert.DeserializeObject<BacktestResults>(content);
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to get backtest results: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Get OHLC candlestick data for chart visualization
        /// </summary>
        public async Task<OhlcData> GetOhlcDataAsync(string taskId)
        {
            try
            {
                var response = await _httpClient.GetAsync($"/api/v1/backtest/{taskId}/ohlc");
                response.EnsureSuccessStatusCode();

                var content = await response.Content.ReadAsStringAsync();
                return JsonConvert.DeserializeObject<OhlcData>(content);
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to get OHLC data: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Get M1 OHLC candlestick data for enhanced playback
        /// </summary>
        public async Task<OhlcData> GetOhlcM1DataAsync(string taskId)
        {
            try
            {
                var response = await _httpClient.GetAsync($"/api/v1/backtest/{taskId}/ohlc-m1");
                response.EnsureSuccessStatusCode();

                var content = await response.Content.ReadAsStringAsync();
                return JsonConvert.DeserializeObject<OhlcData>(content);
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to get M1 OHLC data: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Poll for backtest completion with progress updates
        /// </summary>
        public async Task<BacktestResults> WaitForBacktestCompletionAsync(
            string taskId,
            IProgress<BacktestStatus> progress = null,
            int pollIntervalMs = 1000)
        {
            while (true)
            {
                var status = await GetBacktestStatusAsync(taskId);

                // Report progress
                progress?.Report(status);

                // Check if complete
                if (status.Status == "complete")
                {
                    return await GetBacktestResultsAsync(taskId);
                }

                // Check if failed
                if (status.Status == "failed")
                {
                    throw new Exception($"Backtest failed: {status.Message}");
                }

                // Wait before next poll
                await Task.Delay(pollIntervalMs);
            }
        }

        /// <summary>
        /// Submit backtest and wait for results with progress reporting
        /// </summary>
        public async Task<BacktestResults> RunBacktestAsync(
            BacktestRequest request,
            IProgress<BacktestStatus> progress = null)
        {
            // Submit backtest
            var response = await SubmitBacktestAsync(request);

            // Wait for completion
            return await WaitForBacktestCompletionAsync(response.TaskId, progress);
        }

        /// <summary>
        /// Submit multi-pair backtest request (Phase 8.1)
        /// </summary>
        public async Task<BacktestResponse> SubmitMultiPairBacktestAsync(MultiPairBacktestRequest request)
        {
            var json = JsonConvert.SerializeObject(request);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync("/api/v1/backtest/multi-pair", content);
            response.EnsureSuccessStatusCode();

            var responseContent = await response.Content.ReadAsStringAsync();
            return JsonConvert.DeserializeObject<BacktestResponse>(responseContent);
        }

        /// <summary>
        /// Get multi-pair backtest results (Phase 8.1)
        /// </summary>
        public async Task<MultiPairBacktestResults> GetMultiPairBacktestResultsAsync(string taskId)
        {
            var response = await _httpClient.GetAsync($"/api/v1/backtest/multi-pair/{taskId}/results");
            response.EnsureSuccessStatusCode();

            var content = await response.Content.ReadAsStringAsync();
            return JsonConvert.DeserializeObject<MultiPairBacktestResults>(content);
        }

        /// <summary>
        /// Run multi-pair backtest with progress reporting (Phase 8.2)
        /// </summary>
        public async Task<MultiPairBacktestResults> RunMultiPairBacktestAsync(
            MultiPairBacktestRequest request,
            IProgress<BacktestStatus> progress = null)
        {
            try
            {
                // Validate request
                if (request.Pairs == null || request.Pairs.Count == 0)
                    throw new ArgumentException("At least one pair must be selected");

                if (request.Strategies == null || request.Strategies.Count == 0)
                    throw new ArgumentException("At least one strategy must be selected");

                // Submit backtest (queue it)
                var submitResponse = await SubmitMultiPairBacktestAsync(request);

                // Report initial progress
                progress?.Report(new BacktestStatus
                {
                    Message = $"Running backtest for {request.Pairs.Count} pair(s)...",
                    Progress = 0
                });

                // Poll for completion
                while (true)
                {
                    var status = await GetBacktestStatusAsync(submitResponse.TaskId);

                    // Report progress
                    progress?.Report(status);

                    // Check if complete
                    if (status.Status == "complete")
                    {
                        return await GetMultiPairBacktestResultsAsync(submitResponse.TaskId);
                    }

                    // Check if failed
                    if (status.Status == "failed")
                    {
                        throw new Exception($"Backtest failed: {status.Message}");
                    }

                    // Wait before next poll
                    await Task.Delay(1000);
                }
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to run multi-pair backtest: {ex.Message}", ex);
            }
        }

        public void Dispose()
        {
            _httpClient?.Dispose();
        }
    }
}
