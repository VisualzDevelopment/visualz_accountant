Config = {}

-- # Book keeping time: (Black Money / Config.BookKeepingTime = Seconds)
-- # Example: (1.000.000 / 100) = 10000 Seconds / 166 Minutes / 2,76 Hours
Config.BookKeepingTime = 100

Config.Accountants = {
  {
    -- # Name: The name of the company
    -- # Description: The name that will be displayed in the menus
    Name = "Revisor",

    -- # Job: The job that can access the menu
    -- # IMPORTANT: This is used in the database to create the accountant tables
    -- #            If you need change this, please make sure to change it in the database as well (Ask support if you need help)
    Job = "police",

    -- # Percentage:
    -- # Description: The percentage that the accountant can set for the company (Between 0% and 100%)
    Percentage = {
      min = 0,   -- Det laveste procent virksomheder kan hvidvask
      max = 100, -- Det højeste procent virksomheder kan hvidvask
    },

    -- # Blip: https://docs.fivem.net/docs/game-references/blips/
    -- # Description: The blip that will be displayed on the map
    Blip = {
      Coord = vector3(-582.6794, -347.1439, 34.9355),
      Sprite = 408,
      Color = 5,
      Scale = 0.8,
      Display = 4,
    },

    -- # Menu Locations: Adds a target marker to the location
    -- # Description: The location where the accountant can be opened
    MenuLocations = {
      vector3(-582.72918701172, -347.19741821289, 34.916271209717),
      vector3(-585.8209, -337.5138, 34.9197),
    },

    -- # Boss Only: If true, only the boss can access the feature
    BossOnly = {
      CreateCompany = true,     -- Opret virksomheder
      DeleteCompany = true,     -- Slet virksomheder
      EditCompany = true,       -- Rediger virksomheder

      CreateBookKeeping = true, -- Bogfør / hvidvask penge
      PayoutBookKeeping = true, -- Udbetaling af hvidvasket penge
    }
  },
}
