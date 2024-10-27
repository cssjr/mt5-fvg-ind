//+------------------------------------------------------------------+
//|                                                          Fvg.mq5 |
//|                                         Copyright 2024, rpanchyk |
//|                                      https://github.com/rpanchyk |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2024, rpanchyk"
#property link        "https://github.com/rpanchyk"
#property version     "1.00"
#property description "Indicator shows fair value gaps"

#property indicator_chart_window
#property indicator_plots 1
#property indicator_buffers 3

// types
enum ENUM_BORDER_STYLE
  {
   BORDER_STYLE_SOLID = STYLE_SOLID, // Solid
   BORDER_STYLE_DASH = STYLE_DASH // Dash
  };

// buffers
double FvgHighPriceBuffer[]; // higher price of FVG
double FvgLowPriceBuffer[]; // lower price of FVG
double FvgTrendBuffer[]; // trend of FVG [0: DOWN, 1: UP]

// config
input group "Section :: Main";
input bool InpContinueToMitigation = true; // Continue to mitigation

input group "Section :: Style";
input color InpDownTrendColor = clrLightPink; // Down trend color
input color InpUpTrendColor = clrLightGreen; // Up trend color
input bool InpFill = true; // Fill solid (true) or transparent (false)
input ENUM_BORDER_STYLE InpBoderStyle = BORDER_STYLE_SOLID; // Border line style
input int InpBorderWidth = 2; // Border line width

input group "Section :: Dev";
input bool InpDebugEnabled = false; // Endble debug (verbose logging)

// constants
const string OBJECT_PREFIX = "FVG_";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpDebugEnabled)
     {
      Print("Fvg indicator initialization started");
     }

   ArrayInitialize(FvgHighPriceBuffer, NULL);
   ArrayInitialize(FvgLowPriceBuffer, NULL);
   ArrayInitialize(FvgTrendBuffer, NULL);

   ArraySetAsSeries(FvgHighPriceBuffer, true);
   ArraySetAsSeries(FvgLowPriceBuffer, true);
   ArraySetAsSeries(FvgTrendBuffer, true);

   SetIndexBuffer(0, FvgHighPriceBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(1, FvgLowPriceBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(2, FvgTrendBuffer, INDICATOR_CALCULATIONS);

   if(InpDebugEnabled)
     {
      Print("Fvg indicator initialization finished");
     }
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(InpDebugEnabled)
     {
      Print("Fvg indicator deinitialization started");
     }

   ArrayFree(FvgHighPriceBuffer);
   ArrayFree(FvgLowPriceBuffer);
   ArrayFree(FvgTrendBuffer);

   if(!MQLInfoInteger(MQL_TESTER))
     {
      ObjectsDeleteAll(0, OBJECT_PREFIX);
     }

   if(InpDebugEnabled)
     {
      Print("Fvg indicator deinitialization finished");
     }
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total == prev_calculated)
     {
      return rates_total;
     }

   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   int limit = (int) MathMin(rates_total, rates_total - prev_calculated + 1);
   if(InpDebugEnabled)
     {
      PrintFormat("RatesTotal: %i, PrevCalculated: %i, Limit: %i", rates_total, prev_calculated, limit);
     }

   for(int i = 1; i < limit - 2; i++)
     {
      double rightHighPrice = high[i];
      double rightLowPrice = low[i];
      double midHighPrice = high[i + 1];
      double midLowPrice = low[i + 1];
      double leftHighPrice = high[i + 2];
      double leftLowPrice = low[i + 2];

      datetime rightTime = time[i];
      datetime leftTime = time[i + 2];

      // Up trend
      if(rightLowPrice > leftHighPrice && midLowPrice >= leftLowPrice && midHighPrice <= rightHighPrice)
        {
         FvgHighPriceBuffer[i] = rightLowPrice;
         FvgLowPriceBuffer[i] = leftHighPrice;
         FvgTrendBuffer[i] = 1;

         if(InpContinueToMitigation)
           {
            for(int j = i; j > 0; j--) // Search mitigation bar
              {
               if(j == 1 || (rightLowPrice < high[j] && rightLowPrice > low[j]))
                 {
                  rightTime = time[j];
                  break;
                 }
              }
           }

         DrawBox(leftTime, leftHighPrice, rightTime, rightLowPrice);

         if(InpDebugEnabled)
           {
            PrintFormat("Time: %s, FvgTrendBuffer: %f, FvgLowPriceBuffer: %f, FvgHighPriceBuffer: %f",
                        TimeToString(time[i]), FvgTrendBuffer[i], FvgLowPriceBuffer[i], FvgHighPriceBuffer[i]);
           }
        }

      // Down trend
      if(rightHighPrice < leftLowPrice && midLowPrice <= leftHighPrice && midHighPrice >= rightLowPrice)
        {
         FvgHighPriceBuffer[i] = leftLowPrice;
         FvgLowPriceBuffer[i] = rightHighPrice;
         FvgTrendBuffer[i] = 0;

         if(InpContinueToMitigation)
           {
            for(int j = i; j > 0; j--) // Search mitigation bar
              {
               if(j == 1 || (rightHighPrice < high[j] && rightHighPrice > low[j]))
                 {
                  rightTime = time[j];
                  break;
                 }
              }
           }

         DrawBox(leftTime, leftLowPrice, rightTime, rightHighPrice);

         if(InpDebugEnabled)
           {
            PrintFormat("Time: %s, FvgTrendBuffer: %f, FvgHighPriceBuffer: %f, FvgLowPriceBuffer: %f",
                        TimeToString(time[i]), FvgTrendBuffer[i], FvgHighPriceBuffer[i], FvgLowPriceBuffer[i]);
           }
        }
     }

   return rates_total; // Set prev_calculated on next call
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawBox(datetime leftDt, double leftPrice, datetime rightDt, double rightPrice)
  {
   string objName = OBJECT_PREFIX + TimeToString(leftDt);

   if(ObjectFind(0, objName) < 0)
     {
      ObjectCreate(0, objName, OBJ_RECTANGLE, 0, leftDt, leftPrice, rightDt, rightPrice);

      ObjectSetInteger(0, objName, OBJPROP_COLOR, leftPrice < rightPrice ? InpUpTrendColor :InpDownTrendColor);
      ObjectSetInteger(0, objName, OBJPROP_FILL, InpFill);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, InpBoderStyle);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpBorderWidth);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);
     }
  }
//+------------------------------------------------------------------+
