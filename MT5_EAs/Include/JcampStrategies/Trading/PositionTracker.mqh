//+------------------------------------------------------------------+
//|                                           PositionTracker.mqh     |
//|                                            JcampForexTrader       |
//|                                   Session 16 - 3-Phase Trailing  |
//+------------------------------------------------------------------+
#property copyright "JcampForexTrader"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Position Data Structure (Enhanced for R-Multiple Tracking)       |
//+------------------------------------------------------------------+
struct PositionData
{
    ulong    ticket;
    string   symbol;
    string   strategy;               // TREND_RIDER, RANGE_RIDER, GOLD_TREND_RIDER
    int      signal;                 // 1=BUY, -1=SELL
    double   entryPrice;
    double   originalSLDistance;     // In price units (for R calculation)
    double   maxR;                   // Highest R-multiple achieved
    datetime entryTime;
    bool     trailingActivated;      // Has trailing started? (at +0.5R)
    int      currentPhase;           // 1, 2, or 3
    bool     breakevenSet;           // Has breakeven been set? (RangeRider only)
    double   highWaterMark;          // Track highest/lowest price for trailing
};

//+------------------------------------------------------------------+
//| Position Tracker Class (R-Multiple Based)                        |
//+------------------------------------------------------------------+
class CPositionTracker
{
private:
    PositionData m_positions[];
    int m_count;

public:
    CPositionTracker()
    {
        ArrayResize(m_positions, 0);
        m_count = 0;
    }

    ~CPositionTracker() {}

    //+------------------------------------------------------------------+
    //| Add Position to Tracker                                          |
    //+------------------------------------------------------------------+
    bool AddPosition(ulong ticket,
                     string symbol,
                     string strategy,
                     int signal,
                     double entryPrice,
                     double slDistance)
    {
        // Check if already exists
        if(GetPositionIndex(ticket) >= 0)
            return false; // Already tracking

        // Add new position
        m_count = ArraySize(m_positions);
        ArrayResize(m_positions, m_count + 1);

        m_positions[m_count].ticket = ticket;
        m_positions[m_count].symbol = symbol;
        m_positions[m_count].strategy = strategy;
        m_positions[m_count].signal = signal;
        m_positions[m_count].entryPrice = entryPrice;
        m_positions[m_count].originalSLDistance = slDistance;
        m_positions[m_count].maxR = 0.0;
        m_positions[m_count].entryTime = TimeCurrent();
        m_positions[m_count].trailingActivated = false;
        m_positions[m_count].currentPhase = 0;
        m_positions[m_count].breakevenSet = false;
        m_positions[m_count].highWaterMark = entryPrice;

        return true;
    }

    //+------------------------------------------------------------------+
    //| Get Position Data by Ticket (returns copy)                       |
    //+------------------------------------------------------------------+
    bool GetPosition(ulong ticket, PositionData &outPos)
    {
        int idx = GetPositionIndex(ticket);
        if(idx < 0)
            return false;

        outPos = m_positions[idx];
        return true;
    }

    //+------------------------------------------------------------------+
    //| Remove Position from Tracker                                     |
    //+------------------------------------------------------------------+
    bool RemovePosition(ulong ticket)
    {
        int idx = GetPositionIndex(ticket);
        if(idx < 0)
            return false;

        // Shift array elements
        for(int i = idx; i < ArraySize(m_positions) - 1; i++)
        {
            m_positions[i] = m_positions[i + 1];
        }

        ArrayResize(m_positions, ArraySize(m_positions) - 1);
        return true;
    }

    //+------------------------------------------------------------------+
    //| Calculate Current R-Multiple for Position                        |
    //+------------------------------------------------------------------+
    double CalculateCurrentR(ulong ticket, double currentPrice)
    {
        int idx = GetPositionIndex(ticket);
        if(idx < 0)
            return 0.0;

        if(m_positions[idx].originalSLDistance == 0)
            return 0.0;

        double priceDiff = 0.0;
        if(m_positions[idx].signal > 0) // BUY
            priceDiff = currentPrice - m_positions[idx].entryPrice;
        else // SELL
            priceDiff = m_positions[idx].entryPrice - currentPrice;

        double currentR = priceDiff / m_positions[idx].originalSLDistance;

        // Update max R if higher
        if(currentR > m_positions[idx].maxR)
            m_positions[idx].maxR = currentR;

        return currentR;
    }

    //+------------------------------------------------------------------+
    //| Get Current Phase Based on R-Multiple                            |
    //+------------------------------------------------------------------+
    int GetCurrentPhase(double currentR, double phase1End, double phase2End)
    {
        if(currentR < phase1End)       // 0.5R - 1.0R
            return 1;
        else if(currentR < phase2End)  // 1.0R - 2.0R
            return 2;
        else                            // 2.0R+
            return 3;
    }

    //+------------------------------------------------------------------+
    //| Update Position High Water Mark                                  |
    //+------------------------------------------------------------------+
    bool UpdateHighWaterMark(ulong ticket, double currentPrice)
    {
        int idx = GetPositionIndex(ticket);
        if(idx < 0)
            return false;

        bool updated = false;

        if(m_positions[idx].signal > 0) // BUY
        {
            if(currentPrice > m_positions[idx].highWaterMark)
            {
                m_positions[idx].highWaterMark = currentPrice;
                updated = true;
            }
        }
        else // SELL
        {
            if(currentPrice < m_positions[idx].highWaterMark)
            {
                m_positions[idx].highWaterMark = currentPrice;
                updated = true;
            }
        }

        return updated;
    }

    //+------------------------------------------------------------------+
    //| Mark Trailing as Activated                                       |
    //+------------------------------------------------------------------+
    void SetTrailingActivated(ulong ticket, bool activated)
    {
        int idx = GetPositionIndex(ticket);
        if(idx >= 0)
            m_positions[idx].trailingActivated = activated;
    }

    //+------------------------------------------------------------------+
    //| Set Current Phase                                                |
    //+------------------------------------------------------------------+
    void SetPhase(ulong ticket, int phase)
    {
        int idx = GetPositionIndex(ticket);
        if(idx >= 0)
            m_positions[idx].currentPhase = phase;
    }

    //+------------------------------------------------------------------+
    //| Mark Breakeven as Set (RangeRider)                               |
    //+------------------------------------------------------------------+
    void SetBreakevenSet(ulong ticket, bool set)
    {
        int idx = GetPositionIndex(ticket);
        if(idx >= 0)
            m_positions[idx].breakevenSet = set;
    }

    //+------------------------------------------------------------------+
    //| Get Count of Tracked Positions                                   |
    //+------------------------------------------------------------------+
    int GetCount()
    {
        return ArraySize(m_positions);
    }

    //+------------------------------------------------------------------+
    //| Get Position by Index (for iteration, returns copy)              |
    //+------------------------------------------------------------------+
    bool GetPositionByIndex(int index, PositionData &outPos)
    {
        if(index < 0 || index >= ArraySize(m_positions))
            return false;

        outPos = m_positions[index];
        return true;
    }

private:
    //+------------------------------------------------------------------+
    //| Get Position Index by Ticket                                     |
    //+------------------------------------------------------------------+
    int GetPositionIndex(ulong ticket)
    {
        for(int i = 0; i < ArraySize(m_positions); i++)
        {
            if(m_positions[i].ticket == ticket)
                return i;
        }
        return -1;
    }
};
//+------------------------------------------------------------------+
