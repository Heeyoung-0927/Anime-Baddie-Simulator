--!strict
-- GameConstants
-- Central, read-only configuration shared between server and client.
-- Anything that is a "tuning value" (balance numbers, keys, intervals) lives here
-- so designers can adjust the game without touching gameplay logic.

local GameConstants = {}

-- Economy
GameConstants.STARTING_MONEY = 0
GameConstants.BASE_MONEY_PER_SECOND = 1
GameConstants.PASSIVE_INCOME_INTERVAL = 1 -- seconds between income ticks

-- DataStore
GameConstants.MONEY_DATASTORE_KEY = "BaddieSimulator_Money"
GameConstants.DATASTORE_MAX_RETRIES = 3
GameConstants.DATASTORE_RETRY_DELAY = 2 -- seconds between retries

-- Freeze the table so no runtime code can accidentally mutate a constant.
table.freeze(GameConstants)

return GameConstants
