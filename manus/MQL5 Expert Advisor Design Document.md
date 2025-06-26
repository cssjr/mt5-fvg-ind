# MQL5 Expert Advisor Design Document
## Tokyo Session FVG Trading Strategy

**Author**: Manus AI  
**Date**: June 26, 2025  
**Version**: 1.0

## Executive Summary

This document outlines the comprehensive design for an MQL5 Expert Advisor that implements an automated trading strategy based on Tokyo session breakouts and Fair Value Gap (FVG) patterns. The strategy operates on 5-minute charts for NASDAQ futures (NQ) and includes extensive visual indicators and logging capabilities for validation and debugging purposes.

The Expert Advisor combines session-based trading with price action analysis, utilizing Tokyo session highs and lows as directional bias indicators and Fair Value Gaps as precise entry mechanisms. The system incorporates dynamic position sizing based on account risk percentage, comprehensive order management, and real-time visual feedback through chart objects and detailed logging.

## Strategy Overview

The trading strategy operates in multiple phases, each building upon the previous to create a comprehensive automated trading system. The foundation begins with Tokyo session analysis, where the system continuously monitors and records the highest and lowest prices during the Tokyo trading session, which runs from 7:00 PM to 4:00 AM Eastern Standard Time by default.

Once the Tokyo session concludes, the system enters a monitoring phase where it tracks price movements relative to the established session boundaries. When price breaks above the Tokyo session high, the system switches to a bullish bias, actively seeking long trading opportunities through Fair Value Gap patterns. Conversely, when price breaks below the Tokyo session low, the system adopts a bearish bias and searches for short trading opportunities.

The Fair Value Gap detection mechanism operates continuously during designated trading hours, analyzing three-candle patterns to identify market inefficiencies. For bullish scenarios, the system looks for patterns where a strong upward candle creates a gap between the high of the preceding candle and the low of the following candle. For bearish scenarios, it identifies patterns where a strong downward candle creates a gap between the low of the preceding candle and the high of the following candle.

## Core Components and Architecture

### 1. Session Management System

The session management system forms the backbone of the strategy, responsible for tracking Tokyo session boundaries and maintaining historical session data. This component operates through a continuous monitoring process that begins each day at the configured Tokyo session start time.

During the Tokyo session, the system maintains running calculations of the session high and low prices, updating these values with each new tick. The session high represents the maximum price reached during the Tokyo trading hours, while the session low represents the minimum price. These values are stored in global variables and persist until the next Tokyo session begins.

The system includes built-in handling for daylight saving time transitions and weekend gaps, ensuring accurate session boundary detection regardless of calendar changes. Visual indicators display the current session status through chart labels and color-coded backgrounds, providing immediate feedback about the system's operational state.

### 2. Breakout Detection Engine

The breakout detection engine monitors price movements relative to the established Tokyo session boundaries, implementing configurable confirmation mechanisms to reduce false signals. The system supports two breakout confirmation modes: immediate breakout detection upon price touching the session boundary, and confirmed breakout detection requiring candle closure beyond the boundary.

When a breakout occurs, the system immediately updates the trading bias and logs the event with timestamp and price information. The breakout direction determines the type of Fair Value Gap patterns the system will subsequently monitor. If price breaks above the Tokyo high, only bullish FVG patterns are considered valid. If price breaks below the Tokyo low, only bearish FVG patterns are monitored.

The system includes logic to handle multiple breakouts within the same trading day. If price first breaks above the Tokyo high and later breaks below the Tokyo low, the most recent breakout determines the current trading bias. This ensures the system adapts to changing market conditions throughout the trading session.

### 3. Fair Value Gap Detection Algorithm

The Fair Value Gap detection algorithm represents the most sophisticated component of the system, implementing precise pattern recognition logic to identify three-candle market inefficiencies. The algorithm operates on completed candles only, ensuring pattern confirmation before triggering any trading actions.

For bullish Fair Value Gap detection, the algorithm examines each completed three-candle sequence, identifying patterns where the middle candle shows strong upward momentum and creates a price gap. The system calculates the gap by comparing the high of the first candle with the low of the third candle, ensuring no overlap exists between these price levels.

The bearish Fair Value Gap detection follows similar logic but in reverse, identifying three-candle patterns where the middle candle shows strong downward momentum. The algorithm calculates the gap by comparing the low of the first candle with the high of the third candle, again ensuring no overlap exists.

Each detected Fair Value Gap is assigned a unique identifier and stored in a structured array containing all relevant pattern information, including the gap boundaries, formation time, and associated price levels. This data structure enables efficient pattern management and historical analysis.

### 4. Order Management System

The order management system handles all aspects of trade execution, from initial entry orders through final position closure. The system implements a sophisticated one-trade-at-a-time logic that prevents multiple simultaneous positions while allowing for order replacement when new signals emerge.

When a valid Fair Value Gap pattern is detected and trading conditions are met, the system calculates the appropriate position size based on the configured risk percentage and stop loss distance. The position sizing algorithm ensures that the maximum loss on any single trade does not exceed the specified percentage of account balance.

The system places limit orders at the calculated entry levels, with automatic stop loss and take profit orders attached. For bullish trades, the entry limit order is placed at the low of the third candle in the FVG pattern, with the stop loss positioned below the low of the first candle and take profit set at twice the stop loss distance.

Order modification and cancellation logic ensures that pending orders are properly managed when new signals emerge or market conditions change. The system includes comprehensive error handling for order placement failures and network connectivity issues.

### 5. Risk Management Framework

The risk management framework implements multiple layers of protection to preserve capital and ensure consistent risk exposure across all trades. The primary risk control mechanism operates through dynamic position sizing, calculating lot sizes based on the distance between entry and stop loss levels.

The system includes maximum daily loss limits, automatically suspending trading activities if cumulative losses exceed predefined thresholds. This protection mechanism prevents catastrophic losses during adverse market conditions or system malfunctions.

Additional risk controls include maximum position size limits, minimum and maximum stop loss distances, and trading hour restrictions. These parameters are fully configurable through input variables, allowing for strategy optimization and adaptation to different market conditions.

## Visual Indicators and Chart Objects

### 1. Tokyo Session Visualization

The Tokyo session visualization system creates comprehensive visual feedback about session boundaries and current status. Horizontal lines mark the session high and low levels, extending from the session end time through the current bar. These lines use distinct colors and styles to ensure clear visibility against various chart backgrounds.

The session high line appears in bright green with a solid line style, while the session low line appears in bright red with a solid line style. Line thickness is set to 2 pixels for enhanced visibility, and both lines include text labels displaying the exact price levels and formation times.

A semi-transparent rectangle spans the entire Tokyo session period, providing visual context for the session duration. The rectangle uses a light blue background color with 20% transparency, allowing underlying price action to remain visible while clearly delineating the session boundaries.

### 2. Fair Value Gap Marking

Fair Value Gap patterns receive comprehensive visual marking through colored rectangles that span the gap boundaries and extend forward in time. Bullish FVG patterns are marked with green rectangles using 30% transparency, while bearish FVG patterns use red rectangles with the same transparency level.

Each FVG rectangle includes text labels indicating the pattern type, formation time, and gap boundaries. The labels are positioned at the left edge of the rectangle and use contrasting colors for optimal readability. Font size is set to 10 points with bold formatting to ensure visibility across different chart zoom levels.

The system maintains a maximum of 10 active FVG rectangles on the chart to prevent visual clutter while preserving recent pattern history. Older rectangles are automatically removed as new patterns are detected, maintaining a clean and organized chart appearance.

### 3. Entry and Exit Markers

Trade entry and exit points receive prominent visual marking through arrow objects and text labels. Entry points are marked with large arrow objects pointing in the trade direction, using bright colors that contrast with the chart background. Long entries use green upward arrows, while short entries use red downward arrows.

Exit points are marked with square objects in contrasting colors, with green squares indicating profitable exits and red squares indicating stop loss exits. Each exit marker includes a text label showing the exit reason, profit or loss amount, and trade duration.

The system maintains a complete visual history of all trades, allowing for easy performance analysis and strategy validation. Trade markers persist on the chart until manually removed or until the maximum marker limit is reached.

### 4. Information Panel

A comprehensive information panel displays real-time strategy status and key metrics in the chart's upper-left corner. The panel shows current Tokyo session levels, active trading bias, pending order information, and account statistics.

The information panel updates in real-time as market conditions change, providing immediate feedback about system status and trading opportunities. Color coding indicates different states, with green indicating favorable conditions and red indicating potential issues or inactive states.

## Logging and Debugging Framework

### 1. Comprehensive Event Logging

The logging framework captures all significant events and system states, creating a detailed audit trail for strategy validation and debugging. Log entries include timestamps, event types, relevant price levels, and system states at the time of each event.

Tokyo session events are logged with complete session statistics, including session high and low levels, session duration, and volatility measurements. Breakout events include breakout direction, confirmation method, and subsequent bias changes.

Fair Value Gap detection events are logged with complete pattern details, including all three candle prices, gap boundaries, and pattern validity assessments. Order management events capture order placement, modification, and execution details with associated error codes when applicable.

### 2. Performance Metrics Tracking

The system maintains comprehensive performance metrics including win rate, average profit and loss, maximum drawdown, and risk-adjusted returns. These metrics are calculated in real-time and logged at regular intervals for historical analysis.

Trade-level metrics include entry and exit prices, trade duration, profit or loss amounts, and risk-reward ratios. These details enable detailed performance analysis and strategy optimization over time.

The logging system includes configurable verbosity levels, allowing users to adjust the amount of detail captured based on their specific needs. Debug mode provides maximum detail for troubleshooting, while normal mode captures essential events without excessive detail.

### 3. Error Handling and Alerts

Comprehensive error handling captures and logs all system errors, including order placement failures, data feed interruptions, and calculation errors. Error messages include detailed descriptions, error codes, and suggested corrective actions.

The system includes alert mechanisms for critical events such as trade executions, stop loss hits, and system errors. Alerts can be configured to display on-screen notifications, send email messages, or trigger sound alerts based on user preferences.

## Configuration Parameters

The Expert Advisor includes extensive configuration options through input parameters, allowing users to customize the strategy for different market conditions and risk preferences. Parameters are organized into logical groups for easy navigation and understanding.

### Session Parameters
- Tokyo session start hour (default: 19)
- Tokyo session start minute (default: 0)
- Tokyo session end hour (default: 4)
- Tokyo session end minute (default: 0)
- Breakout confirmation required (default: true)

### Trading Window Parameters
- Trading window 1 start hour (default: 10)
- Trading window 1 end hour (default: 11)
- Trading window 2 start hour (default: 14)
- Trading window 2 end hour (default: 15)
- Enable trading windows (default: true)

### Risk Management Parameters
- Risk percentage per trade (default: 1.0)
- Maximum daily loss percentage (default: 5.0)
- Minimum stop loss points (default: 10)
- Maximum stop loss points (default: 100)
- Maximum position size (default: 10.0 lots)

### Visual Parameters
- Show Tokyo session lines (default: true)
- Show FVG rectangles (default: true)
- Show trade markers (default: true)
- Show information panel (default: true)
- Chart object colors and styles

### Logging Parameters
- Enable logging (default: true)
- Log verbosity level (default: normal)
- Enable alerts (default: true)
- Alert types and methods

This comprehensive design framework ensures the Expert Advisor provides robust trading functionality while maintaining transparency and ease of validation through extensive visual feedback and logging capabilities.

