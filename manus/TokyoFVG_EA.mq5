//+------------------------------------------------------------------+
//|                                                   TokyoFVG_EA.mq5 |
//|                                                          Manus AI |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "Manus AI"
#property link      ""
#property version   "1.00"
#property description "Tokyo Session FVG Trading Strategy"
#property description "Tracks Tokyo session highs/lows and trades Fair Value Gaps"

//--- Input parameters
input group "=== Tokyo Session Settings ==="
input int TokyoStartHour = 19;           // Tokyo session start hour (EST)
input int TokyoStartMinute = 0;          // Tokyo session start minute
input int TokyoEndHour = 4;              // Tokyo session end hour (EST)
input int TokyoEndMinute = 0;            // Tokyo session end minute
input bool BreakoutConfirmation = true;  // Require candle close for breakout confirmation

input group "=== Trading Window Settings ==="
input bool EnableTradingWindows = true;  // Enable specific trading windows
input int TradingWindow1Start = 10;      // Trading window 1 start hour (EST)
input int TradingWindow1End = 11;        // Trading window 1 end hour (EST)
input int TradingWindow2Start = 14;      // Trading window 2 start hour (EST)
input int TradingWindow2End = 15;        // Trading window 2 end hour (EST)

input group "=== Risk Management ==="
input double RiskPercentage = 1.0;       // Risk percentage per trade
input double MaxDailyLoss = 5.0;         // Maximum daily loss percentage
input int MinStopLossPoints = 10;        // Minimum stop loss in points
input int MaxStopLossPoints = 100;       // Maximum stop loss in points
input double MaxPositionSize = 10.0;     // Maximum position size in lots

input group "=== Visual Settings ==="
input bool ShowTokyoLines = true;        // Show Tokyo session high/low lines
input bool ShowFVGRectangles = true;     // Show Fair Value Gap rectangles
input bool ShowTradeMarkers = true;      // Show entry/exit markers
input bool ShowInfoPanel = true;         // Show information panel
input color TokyoHighColor = clrLime;    // Tokyo high line color
input color TokyoLowColor = clrRed;      // Tokyo low line color
input color BullishFVGColor = clrGreen;  // Bullish FVG rectangle color
input color BearishFVGColor = clrRed;    // Bearish FVG rectangle color

input group "=== Logging Settings ==="
input bool EnableLogging = true;         // Enable detailed logging
input bool EnableAlerts = true;          // Enable trading alerts

//--- Global variables
double TokyoHigh = 0;
double TokyoLow = 0;
datetime TokyoSessionStart = 0;
datetime TokyoSessionEnd = 0;
bool TokyoSessionActive = false;
bool TokyoSessionCompleted = false;

enum TRADE_BIAS {
   BIAS_NONE,
   BIAS_BULLISH,
   BIAS_BEARISH
};

TRADE_BIAS CurrentBias = BIAS_NONE;
bool BreakoutOccurred = false;

struct FVGPattern {
   datetime time;
   double high;
   double low;
   TRADE_BIAS bias;
   bool active;
   string objectName;
};

FVGPattern ActiveFVGs[10];
int FVGCount = 0;

double DailyStartBalance = 0;
double DailyPnL = 0;
bool TradingEnabled = true;

//--- Chart object names
string TokyoHighLineName = "TokyoHigh_";
string TokyoLowLineName = "TokyoLow_";
string InfoPanelName = "InfoPanel";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("TokyoFVG EA initialized");
   
   // Initialize daily balance tracking
   DailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Clear any existing chart objects
   ClearChartObjects();
   
   // Initialize arrays
   ArrayInitialize(ActiveFVGs, 0);
   
   if(EnableLogging)
      Print("EA Parameters - Tokyo: ", TokyoStartHour, ":", TokyoStartMinute, " to ", TokyoEndHour, ":", TokyoEndMinute,
            " | Risk: ", RiskPercentage, "% | Breakout Confirmation: ", BreakoutConfirmation);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ClearChartObjects();
   Print("TokyoFVG EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if new bar
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool newBar = (currentBarTime != lastBarTime);
   lastBarTime = currentBarTime;
   
   // Update daily P&L tracking
   UpdateDailyPnL();
   
   // Check daily loss limit
   if(DailyPnL <= -MaxDailyLoss * DailyStartBalance / 100)
   {
      if(TradingEnabled)
      {
         TradingEnabled = false;
         if(EnableLogging)
            Print("Daily loss limit reached. Trading disabled for today.");
         if(EnableAlerts)
            Alert("Daily loss limit reached. Trading disabled.");
      }
      return;
   }
   
   // Update Tokyo session status
   UpdateTokyoSession();
   
   // Check for breakouts if Tokyo session is completed
   if(TokyoSessionCompleted && !BreakoutOccurred)
      CheckBreakouts();
   
   // Detect Fair Value Gaps on new bars
   if(newBar && TradingEnabled)
      DetectFairValueGaps();
   
   // Update visual elements
   UpdateVisuals();
   
   // Manage existing trades
   ManageTrades();
}

//+------------------------------------------------------------------+
//| Update Tokyo session status and levels                          |
//+------------------------------------------------------------------+
void UpdateTokyoSession()
{
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   
   // Check if we're in Tokyo session
   bool inSession = IsInTokyoSession(currentTime);
   
   if(inSession && !TokyoSessionActive)
   {
      // Tokyo session starting
      TokyoSessionActive = true;
      TokyoSessionCompleted = false;
      TokyoSessionStart = TimeCurrent();
      TokyoHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
      TokyoLow = iLow(_Symbol, PERIOD_CURRENT, 0);
      BreakoutOccurred = false;
      CurrentBias = BIAS_NONE;
      
      if(EnableLogging)
         Print("Tokyo session started at ", TimeToString(TokyoSessionStart));
   }
   else if(!inSession && TokyoSessionActive)
   {
      // Tokyo session ending
      TokyoSessionActive = false;
      TokyoSessionCompleted = true;
      TokyoSessionEnd = TimeCurrent();
      
      if(EnableLogging)
         Print("Tokyo session ended. High: ", TokyoHigh, " Low: ", TokyoLow);
      
      // Draw Tokyo session lines
      if(ShowTokyoLines)
         DrawTokyoLines();
   }
   else if(TokyoSessionActive)
   {
      // Update session high/low during active session
      double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
      double currentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
      
      if(currentHigh > TokyoHigh)
         TokyoHigh = currentHigh;
      if(currentLow < TokyoLow)
         TokyoLow = currentLow;
   }
   
   // Reset for new day
   MqlDateTime sessionTime;
   TimeToStruct(TokyoSessionStart, sessionTime);
   if(currentTime.day != sessionTime.day && TokyoSessionCompleted)
   {
      TokyoSessionCompleted = false;
      BreakoutOccurred = false;
      CurrentBias = BIAS_NONE;
      DailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      DailyPnL = 0;
      TradingEnabled = true;
      ClearOldFVGs();
   }
}

//+------------------------------------------------------------------+
//| Check if current time is in Tokyo session                       |
//+------------------------------------------------------------------+
bool IsInTokyoSession(MqlDateTime &time)
{
   int currentHour = time.hour;
   int currentMinute = time.min;
   int currentTimeMinutes = currentHour * 60 + currentMinute;
   
   int startTimeMinutes = TokyoStartHour * 60 + TokyoStartMinute;
   int endTimeMinutes = TokyoEndHour * 60 + TokyoEndMinute;
   
   // Handle overnight session (crosses midnight)
   if(startTimeMinutes > endTimeMinutes)
   {
      return (currentTimeMinutes >= startTimeMinutes || currentTimeMinutes <= endTimeMinutes);
   }
   else
   {
      return (currentTimeMinutes >= startTimeMinutes && currentTimeMinutes <= endTimeMinutes);
   }
}

//+------------------------------------------------------------------+
//| Check for breakouts above/below Tokyo levels                    |
//+------------------------------------------------------------------+
void CheckBreakouts()
{
   if(TokyoHigh == 0 || TokyoLow == 0)
      return;
   
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   double previousPrice = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   bool bullishBreakout = false;
   bool bearishBreakout = false;
   
   if(BreakoutConfirmation)
   {
      // Require candle close beyond level
      bullishBreakout = (previousPrice <= TokyoHigh && currentPrice > TokyoHigh);
      bearishBreakout = (previousPrice >= TokyoLow && currentPrice < TokyoLow);
   }
   else
   {
      // Immediate breakout on touch
      bullishBreakout = (currentPrice > TokyoHigh);
      bearishBreakout = (currentPrice < TokyoLow);
   }
   
   if(bullishBreakout)
   {
      CurrentBias = BIAS_BULLISH;
      BreakoutOccurred = true;
      
      if(EnableLogging)
         Print("Bullish breakout detected above Tokyo high: ", TokyoHigh, " at price: ", currentPrice);
      if(EnableAlerts)
         Alert("Bullish breakout above Tokyo high!");
   }
   else if(bearishBreakout)
   {
      CurrentBias = BIAS_BEARISH;
      BreakoutOccurred = true;
      
      if(EnableLogging)
         Print("Bearish breakout detected below Tokyo low: ", TokyoLow, " at price: ", currentPrice);
      if(EnableAlerts)
         Alert("Bearish breakout below Tokyo low!");
   }
}

//+------------------------------------------------------------------+
//| Detect Fair Value Gap patterns                                  |
//+------------------------------------------------------------------+
void DetectFairValueGaps()
{
   if(CurrentBias == BIAS_NONE || !IsInTradingWindow())
      return;
   
   // Need at least 3 completed bars
   if(iBars(_Symbol, PERIOD_CURRENT) < 4)
      return;
   
   // Get the three candles (1, 2, 3 bars ago - avoiding current incomplete bar)
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, 3);
   double low1 = iLow(_Symbol, PERIOD_CURRENT, 3);
   double open1 = iOpen(_Symbol, PERIOD_CURRENT, 3);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 3);
   
   double high2 = iHigh(_Symbol, PERIOD_CURRENT, 2);
   double low2 = iLow(_Symbol, PERIOD_CURRENT, 2);
   double open2 = iOpen(_Symbol, PERIOD_CURRENT, 2);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   
   double high3 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low3 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double open3 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double close3 = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   // Check for bullish FVG
   if(CurrentBias == BIAS_BULLISH)
   {
      // Middle candle should be bullish and strong
      bool strongBullishCandle = (close2 > open2) && ((close2 - open2) > (high2 - low2) * 0.7);
      
      // Check for gap: high of first candle < low of third candle
      if(strongBullishCandle && high1 < low3)
      {
         // Valid bullish FVG found
         FVGPattern fvg;
         fvg.time = iTime(_Symbol, PERIOD_CURRENT, 1);
         fvg.high = low3;  // Entry level (top of gap)
         fvg.low = high1;  // Bottom of gap
         fvg.bias = BIAS_BULLISH;
         fvg.active = true;
         fvg.objectName = "FVG_Bull_" + TimeToString(fvg.time);
         
         AddFVGPattern(fvg);
         
         if(EnableLogging)
            Print("Bullish FVG detected. Gap: ", high1, " to ", low3, " Entry: ", fvg.high);
         
         // Place buy limit order
         PlaceFVGTrade(fvg);
      }
   }
   
   // Check for bearish FVG
   if(CurrentBias == BIAS_BEARISH)
   {
      // Middle candle should be bearish and strong
      bool strongBearishCandle = (close2 < open2) && ((open2 - close2) > (high2 - low2) * 0.7);
      
      // Check for gap: low of first candle > high of third candle
      if(strongBearishCandle && low1 > high3)
      {
         // Valid bearish FVG found
         FVGPattern fvg;
         fvg.time = iTime(_Symbol, PERIOD_CURRENT, 1);
         fvg.high = low1;  // Top of gap
         fvg.low = high3;  // Entry level (bottom of gap)
         fvg.bias = BIAS_BEARISH;
         fvg.active = true;
         fvg.objectName = "FVG_Bear_" + TimeToString(fvg.time);
         
         AddFVGPattern(fvg);
         
         if(EnableLogging)
            Print("Bearish FVG detected. Gap: ", high3, " to ", low1, " Entry: ", fvg.low);
         
         // Place sell limit order
         PlaceFVGTrade(fvg);
      }
   }
}

//+------------------------------------------------------------------+
//| Check if current time is in trading window                      |
//+------------------------------------------------------------------+
bool IsInTradingWindow()
{
   if(!EnableTradingWindows)
      return true;
   
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   int currentHour = currentTime.hour;
   
   // Check trading window 1
   bool inWindow1 = (currentHour >= TradingWindow1Start && currentHour < TradingWindow1End);
   
   // Check trading window 2
   bool inWindow2 = (currentHour >= TradingWindow2Start && currentHour < TradingWindow2End);
   
   return (inWindow1 || inWindow2);
}

//+------------------------------------------------------------------+
//| Add FVG pattern to array                                        |
//+------------------------------------------------------------------+
void AddFVGPattern(FVGPattern &fvg)
{
   // Remove oldest if array is full
   if(FVGCount >= 10)
   {
      // Remove oldest FVG visual
      ObjectDelete(0, ActiveFVGs[0].objectName);
      
      // Shift array
      for(int i = 0; i < 9; i++)
         ActiveFVGs[i] = ActiveFVGs[i + 1];
      FVGCount = 9;
   }
   
   ActiveFVGs[FVGCount] = fvg;
   FVGCount++;
   
   // Draw FVG rectangle
   if(ShowFVGRectangles)
      DrawFVGRectangle(fvg);
}

//+------------------------------------------------------------------+
//| Place FVG trade                                                 |
//+------------------------------------------------------------------+
void PlaceFVGTrade(FVGPattern &fvg)
{
   // Cancel any existing pending orders
   CancelPendingOrders();
   
   // Close any existing positions
   CloseAllPositions();
   
   double entryPrice, stopLoss, takeProfit;
   ENUM_ORDER_TYPE orderType;
   
   if(fvg.bias == BIAS_BULLISH)
   {
      entryPrice = fvg.high;  // Buy limit at top of gap
      stopLoss = fvg.low - (MinStopLossPoints * _Point);  // Below gap bottom
      orderType = ORDER_TYPE_BUY_LIMIT;
   }
   else
   {
      entryPrice = fvg.low;   // Sell limit at bottom of gap
      stopLoss = fvg.high + (MinStopLossPoints * _Point); // Above gap top
      orderType = ORDER_TYPE_SELL_LIMIT;
   }
   
   // Calculate stop loss distance
   double slDistance = MathAbs(entryPrice - stopLoss);
   
   // Validate stop loss distance
   if(slDistance < MinStopLossPoints * _Point || slDistance > MaxStopLossPoints * _Point)
   {
      if(EnableLogging)
         Print("Stop loss distance invalid: ", slDistance / _Point, " points");
      return;
   }
   
   // Calculate take profit (2:1 risk reward)
   if(fvg.bias == BIAS_BULLISH)
      takeProfit = entryPrice + (slDistance * 2);
   else
      takeProfit = entryPrice - (slDistance * 2);
   
   // Calculate position size
   double lotSize = CalculatePositionSize(slDistance);
   
   if(lotSize <= 0)
   {
      if(EnableLogging)
         Print("Invalid lot size calculated: ", lotSize);
      return;
   }
   
   // Place the order
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_PENDING;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = orderType;
   request.price = entryPrice;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.magic = 12345;
   request.comment = "FVG_" + EnumToString(fvg.bias);
   
   if(OrderSend(request, result))
   {
      if(EnableLogging)
         Print("FVG order placed successfully. Ticket: ", result.order, 
               " Entry: ", entryPrice, " SL: ", stopLoss, " TP: ", takeProfit, " Lots: ", lotSize);
      if(EnableAlerts)
         Alert("FVG trade order placed!");
   }
   else
   {
      if(EnableLogging)
         Print("Failed to place FVG order. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                           |
//+------------------------------------------------------------------+
double CalculatePositionSize(double stopLossDistance)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * RiskPercentage / 100;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   double stopLossInTicks = stopLossDistance / tickSize;
   double riskPerLot = stopLossInTicks * tickValue;
   
   double lotSize = riskAmount / riskPerLot;
   
   // Apply limits
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = MathMin(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), MaxPositionSize);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Cancel all pending orders                                       |
//+------------------------------------------------------------------+
void CancelPendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderSelect(ticket) && OrderGetString(ORDER_SYMBOL) == _Symbol)
      {
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_REMOVE;
         request.order = ticket;
         
         OrderSend(request, result);
      }
   }
}

//+------------------------------------------------------------------+
//| Close all positions                                             |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_DEAL;
         request.symbol = _Symbol;
         request.volume = PositionGetDouble(POSITION_VOLUME);
         request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
         request.position = ticket;
         
         OrderSend(request, result);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage existing trades                                          |
//+------------------------------------------------------------------+
void ManageTrades()
{
   // Check for filled orders and log trade results
   static int lastDealsTotal = 0;
   int currentDealsTotal = HistoryDealsTotal();
   
   if(currentDealsTotal > lastDealsTotal)
   {
      // New deal occurred, check if it's our trade
      for(int i = lastDealsTotal; i < currentDealsTotal; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealSelect(ticket) && HistoryDealGetString(DEAL_SYMBOL) == _Symbol)
         {
            string comment = HistoryDealGetString(DEAL_COMMENT);
            if(StringFind(comment, "FVG_") >= 0)
            {
               double profit = HistoryDealGetDouble(DEAL_PROFIT);
               ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(DEAL_TYPE);
               
               if(EnableLogging)
                  Print("FVG trade result: ", comment, " Profit: ", profit, " Type: ", EnumToString(dealType));
               
               if(ShowTradeMarkers)
                  DrawTradeMarker(HistoryDealGetDouble(DEAL_PRICE), profit > 0, dealType);
            }
         }
      }
      lastDealsTotal = currentDealsTotal;
   }
}

//+------------------------------------------------------------------+
//| Update daily P&L tracking                                       |
//+------------------------------------------------------------------+
void UpdateDailyPnL()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   DailyPnL = currentBalance - DailyStartBalance;
}

//+------------------------------------------------------------------+
//| Draw Tokyo session lines                                        |
//+------------------------------------------------------------------+
void DrawTokyoLines()
{
   if(!ShowTokyoLines)
      return;
   
   string highLineName = TokyoHighLineName + TimeToString(TokyoSessionEnd);
   string lowLineName = TokyoLowLineName + TimeToString(TokyoSessionEnd);
   
   // Draw Tokyo high line
   ObjectCreate(0, highLineName, OBJ_HLINE, 0, 0, TokyoHigh);
   ObjectSetInteger(0, highLineName, OBJPROP_COLOR, TokyoHighColor);
   ObjectSetInteger(0, highLineName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, highLineName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetString(0, highLineName, OBJPROP_TEXT, "Tokyo High: " + DoubleToString(TokyoHigh, _Digits));
   
   // Draw Tokyo low line
   ObjectCreate(0, lowLineName, OBJ_HLINE, 0, 0, TokyoLow);
   ObjectSetInteger(0, lowLineName, OBJPROP_COLOR, TokyoLowColor);
   ObjectSetInteger(0, lowLineName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, lowLineName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetString(0, lowLineName, OBJPROP_TEXT, "Tokyo Low: " + DoubleToString(TokyoLow, _Digits));
}

//+------------------------------------------------------------------+
//| Draw FVG rectangle                                              |
//+------------------------------------------------------------------+
void DrawFVGRectangle(FVGPattern &fvg)
{
   if(!ShowFVGRectangles)
      return;
   
   datetime endTime = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 20; // Extend 20 bars forward
   
   ObjectCreate(0, fvg.objectName, OBJ_RECTANGLE, 0, fvg.time, fvg.high, endTime, fvg.low);
   
   color rectColor = (fvg.bias == BIAS_BULLISH) ? BullishFVGColor : BearishFVGColor;
   ObjectSetInteger(0, fvg.objectName, OBJPROP_COLOR, rectColor);
   ObjectSetInteger(0, fvg.objectName, OBJPROP_FILL, true);
   ObjectSetInteger(0, fvg.objectName, OBJPROP_BACK, true);
   ObjectSetInteger(0, fvg.objectName, OBJPROP_TRANSPARENCY, 70);
   
   string biasText = (fvg.bias == BIAS_BULLISH) ? "Bull" : "Bear";
   ObjectSetString(0, fvg.objectName, OBJPROP_TEXT, biasText + " FVG");
}

//+------------------------------------------------------------------+
//| Draw trade marker                                               |
//+------------------------------------------------------------------+
void DrawTradeMarker(double price, bool profitable, ENUM_DEAL_TYPE dealType)
{
   if(!ShowTradeMarkers)
      return;
   
   string markerName = "TradeMarker_" + TimeToString(TimeCurrent());
   datetime currentTime = TimeCurrent();
   
   ENUM_OBJECT markerType = (dealType == DEAL_TYPE_BUY) ? OBJ_ARROW_UP : OBJ_ARROW_DOWN;
   color markerColor = profitable ? clrGreen : clrRed;
   
   ObjectCreate(0, markerName, markerType, 0, currentTime, price);
   ObjectSetInteger(0, markerName, OBJPROP_COLOR, markerColor);
   ObjectSetInteger(0, markerName, OBJPROP_WIDTH, 3);
   ObjectSetString(0, markerName, OBJPROP_TEXT, profitable ? "Profit" : "Loss");
}

//+------------------------------------------------------------------+
//| Update visual elements                                          |
//+------------------------------------------------------------------+
void UpdateVisuals()
{
   if(!ShowInfoPanel)
      return;
   
   // Create or update info panel
   string panelText = "Tokyo FVG EA\n";
   panelText += "Tokyo High: " + DoubleToString(TokyoHigh, _Digits) + "\n";
   panelText += "Tokyo Low: " + DoubleToString(TokyoLow, _Digits) + "\n";
   panelText += "Bias: " + EnumToString(CurrentBias) + "\n";
   panelText += "Session: " + (TokyoSessionActive ? "Active" : "Inactive") + "\n";
   panelText += "Trading: " + (TradingEnabled ? "Enabled" : "Disabled") + "\n";
   panelText += "Daily P&L: " + DoubleToString(DailyPnL, 2) + "\n";
   panelText += "Active FVGs: " + IntegerToString(FVGCount);
   
   ObjectCreate(0, InfoPanelName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, InfoPanelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, InfoPanelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, InfoPanelName, OBJPROP_YDISTANCE, 30);
   ObjectSetString(0, InfoPanelName, OBJPROP_TEXT, panelText);
   ObjectSetInteger(0, InfoPanelName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, InfoPanelName, OBJPROP_COLOR, clrWhite);
}

//+------------------------------------------------------------------+
//| Clear old FVG patterns                                          |
//+------------------------------------------------------------------+
void ClearOldFVGs()
{
   for(int i = 0; i < FVGCount; i++)
   {
      ObjectDelete(0, ActiveFVGs[i].objectName);
   }
   ArrayInitialize(ActiveFVGs, 0);
   FVGCount = 0;
}

//+------------------------------------------------------------------+
//| Clear all chart objects                                         |
//+------------------------------------------------------------------+
void ClearChartObjects()
{
   ObjectsDeleteAll(0, "TokyoHigh_");
   ObjectsDeleteAll(0, "TokyoLow_");
   ObjectsDeleteAll(0, "FVG_");
   ObjectsDeleteAll(0, "TradeMarker_");
   ObjectDelete(0, InfoPanelName);
}

//+------------------------------------------------------------------+

