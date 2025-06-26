# Research Findings for MQL5 Trading Strategy

## Tokyo Session Hours
Based on research from BabyPips.com:
- **Tokyo Session**: 7:00 PM to 4:00 AM EST (Eastern Standard Time)
- **Note**: Times may shift during Daylight Saving Time transitions
- **Default Parameters**: 
  - Tokyo Start: 19:00 (7:00 PM EST)
  - Tokyo End: 04:00 (4:00 AM EST)

## Fair Value Gap (FVG) Pattern Definition
Based on research from FluxCharts.com:

### Bullish FVG Pattern:
1. Three candle pattern with a large green candle in the middle
2. The **high** of the left candle should NOT overlap with the **low** of the right candle
3. FVG zone: From high of left candle to low of right candle
4. Entry: Buy limit at the **low of the right candle** (top of FVG gap)
5. Stop Loss: Below the **low of the left candle**
6. Take Profit: 2x the stop loss distance

### Bearish FVG Pattern:
1. Three candle pattern with a large red candle in the middle
2. The **low** of the left candle should NOT overlap with the **high** of the right candle
3. FVG zone: From low of left candle to high of right candle
4. Entry: Sell limit at the **high of the right candle** (bottom of FVG gap)
5. Stop Loss: Above the **high of the left candle**
6. Take Profit: 2x the stop loss distance

## Strategy Parameters to Implement:
1. Tokyo session start/end times (configurable)
2. Trading window times (default: 10-11 AM and 2-3 PM NY time)
3. Risk percentage (default: 1% of account balance)
4. Breakout confirmation (boolean parameter)
5. Position sizing based on stop loss distance
6. One trade at a time logic

