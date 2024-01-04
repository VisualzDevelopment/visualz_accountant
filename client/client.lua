--- @type { name: string, deleted: number, created_at: string, cvr: number, updated_at: number, money_washed: number, ownerName: string, accountantName: string, percentage: number, identifier: string, id: number, accountant_identifier: string, accountant: string }?
local currentCompanyData = nil

CreateThread(function()
    -- Loop through all locations and add target for each
    for _, accountant in ipairs(Config.Accountants) do
        for _, coord in ipairs(accountant.MenuLocations) do
            exports.ox_target:addSphereZone({
                coords = coord,
                radius = 1,
                drawSprite = true,
                options = {
                    {
                        icon = 'fas fa-money-bill',
                        label = 'Tilgå ' .. accountant.Name .. '',
                        groups = { accountant.Job },
                        onSelect = function()
                            OpenAccountantContext(accountant)
                        end
                    },
                }
            })
        end

        CreateThread(function()
            local blip = AddBlipForCoord(accountant.Blip.Coord.x, accountant.Blip.Coord.y, accountant.Blip.Coord.z)
            SetBlipSprite(blip, 374)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, 1.0)
            SetBlipColour(blip, 42)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(accountant.Name)
            EndTextCommandSetBlipName(blip)
        end)
    end
end)

-- Accountant context menu
function OpenAccountantContext(accountant)
    local options = {
        {
            title = "Virksomheds liste",
            description = "Søg efter virksomheder, og se deres informationer.",
            icon = "building",
            onSelect = function()
                OpenCompanyList()
            end,
        },
    }

    local accountantConfig = GetAccountantConfig(accountant.Job)
    if not accountantConfig then
        return lib.notify({
            description = 'Der skete en fejl',
            type = 'error',
            icon = 'times'
        })
    end

    if accountantConfig.BossOnly.CreateCompany then
        if ESX.PlayerData.job.name == accountant.Job and ESX.PlayerData.job.grade_name == "boss" then
            table.insert(options, {
                title = "Opret virksomhed",
                description = "Opret en virksomhed for en spiller i nærheden.",
                icon = "folder-plus",
                onSelect = function()
                    CreateCompanyNearbyPlayers()
                end,
            })
        end
    else
        table.insert(options, {
            title = "Opret virksomhed",
            description = "Opret en virksomhed for en spiller i nærheden.",
            icon = "folder-plus",
            onSelect = function()
                CreateCompanyNearbyPlayers()
            end,
        })
    end

    table.insert(options, {
        title = "",
        description = "   ‎   ‎   ‎   ‎   ‎   ‎  Visualz Development | Visualz.dk",
        readOnly = true,
    })

    lib.registerContext({
        id = "accountant_main",
        title = accountant.Name,
        options = options
    })

    lib.showContext("accountant_main")
end

-- Context menu with options for search and list of all companies
function OpenCompanyList()
    lib.registerContext({
        id = "accountant_company_list_pick",
        title = "Virksomheds liste",
        menu = "accountant_main",
        options = {
            {
                title = "Søg efter virksomhed",
                description = "Søger efter en virksomhed ud fra navn.",
                icon = "search",
                onSelect = function()
                    SearchForCompany()
                end,
            },
            {
                title = "Se alle virksomheder",
                description = "Liste over alle virksomheder oprettet.",
                icon = "building",
                onSelect = function()
                    GetAllCompanies()
                end,
            },
        }
    })
    lib.showContext("accountant_company_list_pick")
end

-- Gets a list of nearby players and creates a context menu for them with the option to create a company
function CreateCompanyNearbyPlayers()
    local players = ESX.Game.GetPlayersInArea(GetEntityCoords(cache.ped), 3.0)

    local playersId = {}
    for _, v in ipairs(players) do
        table.insert(playersId, GetPlayerServerId(v))
    end

    local playersInfo = lib.callback.await('visualz_accountant:getPlayersInformation', false, playersId)

    local options = {}

    if #playersInfo == 0 then
        table.insert(options, {
            icon = "user",
            title = "Ingen spillere i nærheden",
            readOnly = true,
        })
    else
        table.insert(options, {
            title = "Spillere i nærheden:",
            readOnly = true,
        })
        for _, v in ipairs(playersInfo) do
            if v.hasCompany then
                table.insert(options, {
                    title = v.name,
                    description = "Ejer allerede en virksomhed.\nVirksomheds navn: " .. v.companyName,
                    icon = "user",
                    disabled = true,
                })
            else
                table.insert(options, {
                    title = v.name,
                    description = "Opret virksomhed for " .. v.name,
                    icon = "user",
                    onSelect = function()
                        CreateCompanyForPlayer(v.source, v.name)
                    end,
                })
            end
        end

        table.sort(options, function(a, b)
            return not a.disabled and b.disabled
        end)
    end

    lib.registerContext({
        id = "accountant_create_company_nearby_players",
        title = "Opret virksomhed",
        menu = "accountant_main",
        options = options
    })

    lib.showContext("accountant_create_company_nearby_players")
end

-- Creates a company for the player
function CreateCompanyForPlayer(companyOwnerId, companyOwnerName)
    local sendRequestToPlayer = lib.alertDialog({
        header = "Oprettelse af virksomhed",
        content = 'Du er ved at oprette en virksomhed for ' .. companyOwnerName .. '. Hvis du forsætter vil kunden blive spurgt om virksomheds navn.',
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Forsæt',
            cancel = 'Annuller'
        }
    })

    if sendRequestToPlayer == "cancel" then
        return CreateCompanyNearbyPlayers()
    elseif sendRequestToPlayer == "confirm" then
        local didCompanyGetCreated = lib.callback.await('visualz_accountant:createCompany', false, companyOwnerId)
        lib.notify(didCompanyGetCreated)
    end
end

-- Search for a company by name
function SearchForCompany()
    local input = lib.inputDialog('Søg efter virksomhed', {
        { type = 'input', label = 'Virksomhed navn', description = 'Skriv navnet på virksomhed', icon = 'building', required = true },
    })

    if input == nil then
        return lib.showContext("accountant_company_list_pick")
    end

    local companies = lib.callback.await('visualz_accountant:searchCompanyByName', false, input[1])
    DisplayCompanies(companies)
end

-- Get all companies
function GetAllCompanies()
    local companies = lib.callback.await('visualz_accountant:getAllCompanies', false)
    DisplayCompanies(companies)
end

function DisplayCompanies(companies)
    local options = {}

    if #companies == 0 then
        table.insert(options, {
            title = "Kunne ikke finde nogle virksomheder",
            icon = "building",
            readOnly = true,
        })
    else
        for _, v in ipairs(companies) do
            table.insert(options, {
                title = v.name,
                description = "Ejer: " .. v.ownerName .. "\nProcent sats: " .. v.percentage .. "%" .. "\nOprettet af: " .. v.accountantName,
                icon = "building",
                onSelect = function()
                    currentCompanyData = v
                    OpenCompany()
                end,
            })
        end

        table.sort(options, function(a, b)
            return a.title > b.title
        end)
    end

    lib.registerContext({
        id = "accountant_company_list",
        title = "Alle virksomheder (" .. #companies .. ")",
        menu = "accountant_company_list_pick",
        options = options
    })

    lib.showContext("accountant_company_list")
end

-- Open current company and show options
function OpenCompany()
    if currentCompanyData == nil then
        return lib.notify({
            description = 'Der skete en fejl',
            type = 'error',
            icon = 'times'
        })
    end

    local options = {
        {
            title = "Virksomheds informationer",
            description = "Vis informationer om virksomheden",
            icon = "fa-solid fa-circle-info",
            onSelect = function()
                OpenCompanyInformation()
            end,
        },
        {
            title = "Virksomheds muligheder",
            description = "Muligheder for virksomheden",
            icon = "fa-solid fa-building-circle-arrow-right",
            onSelect = function()
                OpenCompanyOptions()
            end,
        },
    }

    lib.registerContext({
        id = "accountant_company_show",
        title = tostring(currentCompanyData.name),
        menu = "accountant_company_list_pick",
        options = options
    })

    lib.showContext("accountant_company_show")
end

-- Show information about a company
function OpenCompanyInformation()
    if currentCompanyData == nil then
        return lib.notify({
            description = 'Der skete en fejl',
            type = 'error',
            icon = 'times'
        })
    end

    local options = {
        {
            title = "Navn",
            description = currentCompanyData.name,
            icon = "fa-solid fa-building",
            readOnly = true,
        },
        {
            title = "CVR Nummer",
            description = tostring(currentCompanyData.cvr),
            icon = "fa-solid fa-id-card",
            readOnly = true,
        },
        {
            title = "Indehaver",
            description = currentCompanyData.ownerName,
            icon = "user",
            readOnly = true,
        },
        {
            title = "Procent sats",
            description = "Bogfører til " .. currentCompanyData.percentage .. "%",
            icon = "percent",
            readOnly = true,
        },
        {
            title = "Oprettet af",
            description = currentCompanyData.accountantName,
            icon = "user",
            readOnly = true,
        },
        {
            title = "Oprettet d.",
            description = currentCompanyData.created_at,
            icon = "calendar",
            readOnly = true,
        },
    }

    lib.registerContext({
        id = "accountant_company_information",
        title = "Virksomhed informationer",
        menu = "accountant_company_show",
        options = options
    })

    lib.showContext("accountant_company_information")
end

-- Show options for a company
function OpenCompanyOptions()
    if currentCompanyData == nil then
        return lib.notify({
            description = 'Der skete en fejl',
            type = 'error',
            icon = 'times'
        })
    end

    local accountantConfig = GetAccountantConfig(ESX.PlayerData.job.name)
    if not accountantConfig then
        return lib.notify({
            description = 'Der skete en fejl',
            type = 'error',
            icon = 'times'
        })
    end

    local options = {}

    if accountantConfig.BossOnly.CreateBookKeeping then
        if ESX.PlayerData.job.name == currentCompanyData.accountant and ESX.PlayerData.job.grade_name == "boss" then
            table.insert(options, {
                title = "Bogfør kontanter",
                description = "Bogfør kontanter for kunder.",
                icon = "wallet",
                onSelect = function()
                    CompanyBookKeeping()
                end,
            })
        end
    else
        table.insert(options, {
            title = "Bogfør kontanter",
            description = "Bogfør kontanter for kunder.",
            icon = "wallet",
            onSelect = function()
                CompanyBookKeeping()
            end,
        })
    end

    table.insert(options, {
        title = "Aktive bogføringer",
        description = "Se aktive bogføringer for virksomheden.",
        icon = "hourglass-half",
        onSelect = function()
            OpenCompanyBookKeepingProcessList()
        end,
    })

    table.insert(options, {
        title = "Se bogføringer",
        description = "Se alle bogføringer for virksomheden.",
        icon = "book",
        onSelect = function()
            OpenCompanyBookKeepingList()
        end,
    })

    if accountantConfig.BossOnly.EditCompany then
        if ESX.PlayerData.job.name == currentCompanyData.accountant and ESX.PlayerData.job.grade_name == "boss" then
            table.insert(options, {
                title = "Rediger virksomhed",
                description = "Rediger virksomheden.",
                icon = "pen-to-square",
                onSelect = function()
                    EditCompany()
                end,
            })
        end
    else
        table.insert(options, {
            title = "Rediger virksomhed",
            description = "Rediger virksomheden.",
            icon = "pen-to-square",
            onSelect = function()
                EditCompany()
            end,
        })
    end
    if accountantConfig.BossOnly.DeleteCompany then
        if ESX.PlayerData.job.name == currentCompanyData.accountant and ESX.PlayerData.job.grade_name == "boss" then
            table.insert(options, {
                title = "Slet virksomhed",
                description = "Slet virksomheden permanent, og alle informationer.",
                icon = "building-circle-xmark",
                onSelect = function()
                    DeleteCompany()
                end,
            })
        end
    else
        table.insert(options, {
            title = "Slet virksomhed",
            description = "Slet virksomheden permanent, og alle informationer.",
            icon = "building-circle-xmark",
            onSelect = function()
                DeleteCompany()
            end,
        })
    end

    lib.registerContext({
        id = "accountant_company_options",
        title = "Virksomheds muligheder",
        menu = "accountant_company_show",
        onBack = function()
            OpenCompany()
        end,
        options = options
    })

    lib.showContext("accountant_company_options")
end

function CompanyBookKeeping()
    if currentCompanyData == nil then
        return lib.notify({
            description = 'Der skete en fejl',
            type = 'error',
            icon = 'times'
        })
    end

    local alert = lib.alertDialog({
        header = "Bogfør kontanter",
        content = 'Du er ved at bogføre kontanter for ' .. currentCompanyData.name .. '. Hvis du forsætter vil kunden blive spurgt om beløb.',
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Forsæt',
            cancel = 'Annuller'
        }
    })

    if alert == "cancel" then
        return OpenCompanyOptions()
    end

    local response = lib.callback.await('visualz_accountant:createBookKeeping', false, currentCompanyData.id)
    lib.notify(response)
end

function OpenCompanyBookKeepingList()
    if currentCompanyData == nil then
        return lib.notify({
            description = 'Der skete en fejl',
            type = 'error',
            icon = 'times'
        })
    end

    local bookKeepings = lib.callback.await('visualz_accountant:getCompanyBookKeepings', false, currentCompanyData.id)

    local options = {}

    if #bookKeepings == 0 then
        table.insert(options, {
            icon = "calendar",
            title = "Ingen bogføringer fundet",
            readOnly = true,
        })
    else
        for _, v in ipairs(bookKeepings) do
            table.insert(options, {
                title = v.ending_at,
                description = "Status: Gennemført" .. "\nBogført af: " .. v.accountant_name,
                readOnly = true,
                metadata = {
                    { label = "Beløb indsat", value = ESX.Math.GroupDigits(v.amount_inserted) },
                    { label = "Beløb udkom",  value = ESX.Math.GroupDigits(v.amount_receiving) },
                    { label = "Procent sats", value = v.percentage .. "%" },
                    { label = "Bogført d",    value = v.created_at },
                    { label = "Gennemført d", value = v.ending_at }
                },
                icon = "file-circle-check",
            })
        end
    end

    lib.registerContext({
        id = "accountant_company_book_keepings",
        title = "Bogføringer (" .. #bookKeepings .. ")",
        menu = "accountant_company_options",
        options = options
    })

    lib.showContext("accountant_company_book_keepings")
end

function HasPermToPayout()
    if currentCompanyData == nil then
        return false
    end

    local accountantConfig = GetAccountantConfig(ESX.PlayerData.job.name)
    if accountantConfig == nil then
        return false
    end

    if accountantConfig.BossOnly.PayoutBookKeeping then
        if ESX.PlayerData.job.name == currentCompanyData.accountant and ESX.PlayerData.job.grade_name == "boss" then
            return true
        end
    else
        return true
    end
end

function OpenCompanyBookKeepingProcessList()
    if currentCompanyData == nil then
        return lib.notify({
            description = 'Der skete en fejl',
            type = 'error',
            icon = 'times'
        })
    end

    local bookKeepingProcessList = lib.callback.await('visualz_accountant:getCompanyBookKeepingProcessList', false, currentCompanyData.id)

    local options = {}

    if #bookKeepingProcessList == 0 then
        table.insert(options, {
            icon = "calendar",
            title = "Ingen aktive bogføringer fundet",
            readOnly = true,
        })
    else
        table.insert(options, {
            title = "Opdater bogføringer",
            description = "Genopfrisk listen over aktive bogføringer",
            icon = "sync",
            onSelect = function()
                OpenCompanyBookKeepingProcessList()
            end,
        })
        for _, v in ipairs(bookKeepingProcessList) do
            local status = v.percentageDifference == 100 and true or false
            if status then
                local permText = HasPermToPayout() and "Klik for at udbetale bogføringen" or "Du har ikke tilladelse til at udbetale bogføringen"
                table.insert(options, {
                    title = v.ending_at,
                    progress = v.percentageDifference,
                    colorScheme = ProgressColorScheme(v.percentageDifference),
                    description = "Status: Gennemført" .. "\nBogført af: " .. v.accountant_name .. "\n\n" .. permText,
                    readOnly = not HasPermToPayout(),
                    metadata = {
                        { label = "Beløb indsat", value = ESX.Math.GroupDigits(v.amount_inserted) },
                        { label = "Beløb udkom",  value = ESX.Math.GroupDigits(v.amount_receiving) },
                        { label = "Procent sats", value = v.percentage .. "%" },
                        { label = "Bogført d",    value = v.created_at },
                        { label = "Gennemført d", value = v.ending_at }
                    },
                    icon = "calendar",
                    onSelect = function()
                        local payOutResponse = lib.callback.await('visualz_accountant:payOutBookKeeping', false, v.id)
                        lib.notify(payOutResponse)
                        OpenCompanyBookKeepingProcessList()
                    end,
                })
            else
                table.insert(options, {
                    title = v.ending_at,
                    progress = v.percentageDifference,
                    colorScheme = ProgressColorScheme(v.percentageDifference),
                    description = "Status: Afventer" .. "\nBogført af: " .. v.accountant_name .. "\n\n Der er " .. v.timeLeftString .. " tilbage",
                    readOnly = true,
                    metadata = {
                        { label = "Beløb indsat", value = ESX.Math.GroupDigits(v.amount_inserted) },
                        { label = "Beløb udkom",  value = ESX.Math.GroupDigits(v.amount_receiving) },
                        { label = "Procent sats", value = v.percentage .. "%" },
                        { label = "Bogført d",    value = v.created_at },
                        { label = "Gennemføre d", value = v.ending_at }
                    },
                    icon = "calendar",
                })
            end
        end
    end

    lib.registerContext({
        id = "accountant_company_book_keeping_process_list",
        title = "Aktive bogføringer (" .. #bookKeepingProcessList .. ")",
        menu = "accountant_company_options",
        options = options
    })

    lib.showContext("accountant_company_book_keeping_process_list")
end

function EditCompany()
    if currentCompanyData == nil then
        return lib.notify({
            description = 'Der skete en fejl',
            type = 'error',
            icon = 'times'
        })
    end

    local input = lib.inputDialog('Rediger ' .. currentCompanyData.name, {
        { type = 'input',  label = 'Virksomheds navn', description = 'Rediger navnet på virksomheden', icon = 'building', default = currentCompanyData.name,       required = true },
        { type = 'number', label = 'Sats',             description = 'Rediger procent sats',           icon = 'percent',  default = currentCompanyData.percentage, required = true },
    })

    if input == nil then
        return lib.showContext("accountant_company_options")
    end

    local editCompanyResponse = lib.callback.await('visualz_accountant:editCompany', false, currentCompanyData.id, input[1], input[2])

    if editCompanyResponse.type == "success" then
        currentCompanyData.name = tostring(input[1])
        local parsedPercentage = tonumber(input[2])
        if parsedPercentage then
            currentCompanyData.percentage = parsedPercentage
        end
    end

    lib.notify(editCompanyResponse)
    OpenCompanyOptions()
end

function DeleteCompany()
    if currentCompanyData == nil then
        return lib.notify({
            description = 'Der skete en fejl',
            type = 'error',
            icon = 'times'
        })
    end

    local wantToDelete = lib.alertDialog({
        header = "Slet virksomheden",
        content = 'Du er ved at slette virksomheden ' .. currentCompanyData.name .. '. Hvis du forsætter vil virksomheden blive slettet permanent.',
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Slet virksomhed',
            cancel = 'Annuller'
        }
    })

    if wantToDelete ~= "confirm" then
        return OpenCompanyOptions()
    end

    local deleteCompanyResponse = lib.callback.await('visualz_accountant:deleteCompany', false, currentCompanyData.id)

    if deleteCompanyResponse.type == "success" then
        currentCompanyData = nil
        lib.showContext("accountant_main")
    else
        OpenCompanyOptions()
    end

    lib.notify(deleteCompanyResponse)
end

-- Customer Request - Accept/Decline dialog and company name input
lib.callback.register("visualz_accountant:requestCompanyData", function()
    if lib.getOpenContextMenu() ~= nil then
        lib.closeContext()
    end

    if lib.getOpenMenu() ~= nil then
        lib.closeMenu()
    end

    local dialog = lib.alertDialog({
        header = "Oprettelse af virksomhed",
        content = 'Du har modtaget en forespørgsel om at oprette en virksomhed. Vil du oprette en virksomhed?',
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Opret virksomhed',
            cancel = 'Annuller'
        }
    })

    if dialog == "cancel" then
        return false
    end

    local input = lib.inputDialog('Opret virksomhed',
        {
            { type = 'input', label = 'Virksomheds navn', description = 'Skriv navnet på virksomheden', icon = 'building', required = true },
        },
        {
            {
                allowCancel = true,
            },
        }
    )

    if input == nil then
        return false
    end

    return input[1]
end)

-- Accountant Request - Accept/Decline the company name the customer has entered
lib.callback.register("visualz_accountant:companyDataResponse", function(companyOwner, companyName)
    if lib.getOpenContextMenu() ~= nil then
        lib.closeContext()
    end

    if lib.getOpenMenu() ~= nil then
        lib.closeMenu()
    end

    local accountantConfig = GetAccountantConfig(ESX.PlayerData.job.name)
    if accountantConfig == nil then
        return false
    end

    local year, month, day, hour, minute, second = GetLocalTime()

    local input = lib.inputDialog('Opret virksomheden',
        {
            { type = 'input',    label = 'Virksomheds ejer',     description = "Navnet på virksomheds ejeren", icon = 'user',                                                                                 default = companyOwner,                disabled = true },
            { type = 'input',    label = 'Virksomheds navn',     description = 'Navnet på virksomheden',       icon = 'building',                                                                             default = companyName,                 disabled = true },
            { type = 'number',   label = 'Procentsats',          description = 'Procentsats for bogføring.',   icon = 'percentage',                                                                           min = accountantConfig.Percentage.min, max = accountantConfig.Percentage.max, default = accountantConfig.Percentage.min, required = true },
            { type = 'date',     label = 'Dato for oprettelse',  icon = { 'far', 'calendar' },                 default = year .. "/" .. month .. "/" .. day .. " " .. hour .. ":" .. minute .. ":" .. second, format = "DD/MM/YYYY hh:mm:ss",        disabled = true },
            { type = 'checkbox', label = 'Accepter oprettelse?', description = "Godkender du virksomheden",    required = true },
        })

    if input == nil then
        return false
    end

    return input[4], input[3]
end)

-- Customer Request - Accept/Decline dialog and company name input
lib.callback.register("visualz_accountant:requestBookKeepingData", function(companyName, percentage, ownerName, askAgain)
    if lib.getOpenContextMenu() ~= nil then
        lib.closeContext()
    end

    if lib.getOpenMenu() ~= nil then
        lib.closeMenu()
    end

    if not askAgain then
        local dialog = lib.alertDialog({
            header = "Bogføring af kontanter",
            content = 'Du har modtaget en forespørgsel om at bogføre kontanter. Vil du bogføre kontanter?',
            centered = true,
            cancel = true,
            labels = {
                confirm = 'Bogfør kontanter',
                cancel = 'Annuller'
            }
        })

        if dialog == "cancel" then
            return false
        end
    end

    local year, month, day, hour, minute, second = GetLocalTime()

    local input = lib.inputDialog('Bogfør for ' .. companyName,
        {
            { type = 'input',  label = 'Virksomheds stifter', description = "Navnet på ejeren af virksomheden", icon = 'user',                                                                                 default = ownerName,            disabled = true },
            { type = 'input',  label = 'Virksomhed navn',     description = 'Navnet på virksomheden',           icon = 'building',                                                                             default = companyName,          disabled = true },
            { type = 'number', label = 'Procentsats',         description = 'Procentsats for bogføring.',       icon = 'percentage',                                                                           default = percentage,           disabled = true },
            { type = 'number', label = 'Beløb',               description = 'Beløb som skal bogføres',          icon = 'sack-dollar',                                                                          required = true },
            { type = 'date',   label = 'Dato for bogføring',  icon = { 'far', 'calendar' },                     default = day .. "/" .. month .. "/" .. year .. " " .. hour .. ":" .. minute .. ":" .. second, format = "DD/MM/YYYY hh:mm:ss", disabled = true }
        },
        {
            {
                allowCancel = true,
            },
        }
    )

    if input == nil then
        return false
    end

    return input[4]
end)

-- Accountant Request - Accept/Decline the company name the customer has entered
lib.callback.register("visualz_accountant:companyBookKeepingResponse", function(companyOwner, companyName, amountToBookKeep, percentage)
    if lib.getOpenContextMenu() ~= nil then
        lib.closeContext()
    end

    if lib.getOpenMenu() ~= nil then
        lib.closeMenu()
    end

    local accountantConfig = GetAccountantConfig(ESX.PlayerData.job.name)
    if accountantConfig == nil then
        return false
    end

    local year, month, day, hour, minute, second = GetLocalTime()

    local input = lib.inputDialog('Bogfør kontanter', {
        { type = 'input',    label = 'Virksomheds ejer',    description = "Navnet på virksomheds ejeren",  icon = 'user',                                                                                 default = companyOwner,         disabled = true },
        { type = 'input',    label = 'Virksomheds navn',    description = 'Navnet på virksomheden',        icon = 'building',                                                                             default = companyName,          disabled = true },
        { type = 'number',   label = 'Procentsats',         description = 'Procentsats for bogføring.',    icon = 'percentage',                                                                           default = percentage,           disabled = true },
        { type = 'number',   label = 'Bogførings beløb',    description = 'Beløb som kunden vil bogføre.', icon = 'sack-dollar',                                                                          default = amountToBookKeep,     disabled = true },
        { type = 'date',     label = 'Dato for bogføring',  icon = { 'far', 'calendar' },                  default = year .. "/" .. month .. "/" .. day .. " " .. hour .. ":" .. minute .. ":" .. second, format = "DD/MM/YYYY hh:mm:ss", disabled = true },
        { type = 'checkbox', label = 'Accepter bogføring?', description = "Godkender du bogføringen",      required = true },
    })

    if input == nil then
        return false
    end

    return input[4], input[3]
end)

function ProgressColorScheme(progress)
    if progress >= 0 and progress <= 33 then
        return "red"
    elseif progress > 33 and progress < 66 then
        return "yellow"
    elseif progress >= 66 then
        return "green"
    end
end

function GetAccountantConfig(job)
    local accountantConfig = nil
    for _, accountant in pairs(Config.Accountants) do
        if accountant.Job == job then
            accountantConfig = accountant
            break
        end
    end
    return accountantConfig
end
