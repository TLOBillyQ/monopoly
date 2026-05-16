Feature: Foundation integer parsing

Background:
  Given project acceptance step handlers are loaded

Scenario Outline: Parse integer text
  Given a text value <raw>
  When the project converts it to an integer
  Then the integer result is <result>

Examples:
  | raw | result |
  | 12  | 12     |
  | -7  | -7     |
