local companyRequests = {}

if GetCurrentResourceName() ~= "visualz_accountant" then
    print("[" .. GetCurrentResourceName() .. "] ^1WARNING^7: This resource is not named 'visualz_accountant' but '" .. GetCurrentResourceName() .. "'")
    Wait(100)
    StopResource(GetCurrentResourceName())
end

CreateThread(function()
    while true do
        Wait(1000)

        for k, v in pairs(companyRequests) do
            if v.timeout > 0 then
                companyRequests[k].timeout = v.timeout - 1
            else
                companyRequests[k] = nil

                local xPlayer = ESX.GetPlayerFromId(v.accountantSource)
                if xPlayer then
                    TriggerClientEvent("visualz_accountant:companyRequestDone", xPlayer.source, "timeout")
                    TriggerClientEvent("ox_lib:notify", k, {
                        description = 'Du svaret ikke i tide',
                        type = 'error',
                        icon = 'times'
                    })
                end
            end
        end
    end
end)


MySQL.ready(function()
    MySQL.query('SHOW TABLES LIKE \'visualz_accountant_book_keeping\'', {}, function(tableExists)
        if not tableExists or #tableExists == 0 then
            local createTableResponse = MySQL.Sync.execute(
                'CREATE TABLE IF NOT EXISTS `visualz_accountant_book_keeping` (' ..
                '`id` int(11) NOT NULL AUTO_INCREMENT,' ..
                '`company_id` int(11) NOT NULL,' ..
                '`accountant` varchar(255) NOT NULL,' ..
                '`accountant_identifier` varchar(255) NOT NULL,' ..
                '`percentage` int(11) NOT NULL,' ..
                '`amount_inserted` int(11) NOT NULL,' ..
                '`amount_receiving` int(11) NOT NULL,' ..
                '`created_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),' ..
                '`ending_at` timestamp NOT NULL DEFAULT current_timestamp(),' ..
                '`completed` int(11) NOT NULL DEFAULT 0,' ..
                'PRIMARY KEY (`id`)' ..
                ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci',
                {})
            if createTableResponse then
                print("[" .. GetCurrentResourceName() .. "] ^2SUCCESS^7: Created table 'visualz_accountant_book_keeping'")
            else
                print("[" .. GetCurrentResourceName() .. "] ^1ERROR^7: Could not create table 'visualz_accountant_book_keeping'")
            end
        end
    end)

    MySQL.query('SHOW TABLES LIKE \'visualz_accountant_company\'', {}, function(tableExists)
        if not tableExists or #tableExists == 0 then
            local createTableResponse = MySQL.Sync.execute(
                'CREATE TABLE IF NOT EXISTS `visualz_accountant_company` (' ..
                '`id` int(11) NOT NULL AUTO_INCREMENT,' ..
                '`identifier` varchar(255) NOT NULL,' ..
                '`name` varchar(255) NOT NULL,' ..
                '`cvr` int(11) NOT NULL,' ..
                '`percentage` int(11) NOT NULL,' ..
                '`accountant_identifier` varchar(255) NOT NULL,' ..
                '`accountant` varchar(255) NOT NULL,' ..
                '`money_washed` int(11) NOT NULL DEFAULT 0,' ..
                '`deleted` int(11) NOT NULL DEFAULT 0,' ..
                '`created_at` timestamp NOT NULL DEFAULT current_timestamp(),' ..
                'PRIMARY KEY (`id`)' ..
                ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci',
                {})

            if createTableResponse then
                print("[" .. GetCurrentResourceName() .. "] ^2SUCCESS^7: Created table 'visualz_accountant_company'")
            else
                print("[" .. GetCurrentResourceName() .. "] ^1ERROR^7: Could not create table 'visualz_accountant_company'")
            end
        end
    end)
end)


lib.callback.register('visualz_accountant:getPlayersInformation', function(source, players)
    local xPlayer = ESX.GetPlayerFromId(source)

    local accountantJob = GetAccountantJob(xPlayer, "CreateCompany")
    if not accountantJob then
        return {}
    end

    local playersInfo = {}

    for i = #players, 1, -1 do
        local xPlayer = ESX.GetPlayerFromId(players[i])
        if xPlayer then
            local doesCompanyExist = MySQL.single.await('SELECT `identifier`, `name` FROM `visualz_accountant_company` WHERE `identifier` = ? AND `accountant` = ? AND `deleted` = 0 LIMIT 1', {
                xPlayer.identifier, accountantJob
            })

            table.insert(playersInfo, {
                source = xPlayer.source,
                name = xPlayer.getName(),
                hasCompany = doesCompanyExist ~= nil,
                companyName = doesCompanyExist and doesCompanyExist.name or nil,
            })
        end
    end

    local doesCompanyExist = MySQL.single.await('SELECT `identifier`, `name` FROM `visualz_accountant_company` WHERE `identifier` = ? AND `accountant` = ? AND `deleted` = 0 LIMIT 1', {
        xPlayer.identifier, accountantJob
    })

    table.insert(playersInfo, {
        source = xPlayer.source,
        name = xPlayer.getName(),
        hasCompany = doesCompanyExist ~= nil,
        companyName = doesCompanyExist and doesCompanyExist.name or nil,
    })

    return playersInfo
end)

lib.callback.register('visualz_accountant:getAllCompanies', function()
    local xPlayer = ESX.GetPlayerFromId(source)

    local accountantJob = GetAccountantJob(xPlayer)

    if not accountantJob then
        return {}
    end

    local companies = MySQL.query.await('SELECT * FROM `visualz_accountant_company` WHERE `accountant` = ?', {
        accountantJob
    })

    return FormatCompanies(companies)
end)

lib.callback.register('visualz_accountant:searchCompanyByName', function(source, name)
    local xPlayer = ESX.GetPlayerFromId(source)

    local accountantJob = GetAccountantJob(xPlayer)

    if not accountantJob then
        return {}
    end

    local companies = MySQL.query.await(
        'SELECT * FROM `visualz_accountant_company` WHERE `name` LIKE ? AND `accountant` = ?', {
            '%' .. name .. '%', accountantJob
        })

    return FormatCompanies(companies)
end)

function FormatCompanies(companies)
    local formattedCompanies = companies
    :: continue ::
    for i = #companies, 1, -1 do
        if companies[i].deleted == 1 then
            table.remove(formattedCompanies, i)
            goto continue
        end

        local playerName = MySQL.single.await(
            'SELECT `firstname`, `lastname` FROM `users` WHERE `identifier` = ? LIMIT 1', {
                formattedCompanies[i].identifier
            })

        local accountantName = MySQL.single.await(
            'SELECT `firstname`, `lastname` FROM `users` WHERE `identifier` = ? LIMIT 1', {
                formattedCompanies[i].accountant_identifier
            })

        local created_at_number = tonumber(formattedCompanies[i].created_at)


        if created_at_number then
            formattedCompanies[i].created_at = os.date("%Y-%m-%d %H:%M:%S", math.floor(created_at_number) / 1000)
        end

        if playerName and accountantName then
            formattedCompanies[i].ownerName = playerName.firstname .. ' ' .. playerName.lastname
            formattedCompanies[i].accountantName = accountantName.firstname .. ' ' .. accountantName.lastname
        else
            table.remove(formattedCompanies, i)
        end
    end
    return formattedCompanies
end

lib.callback.register("visualz_accountant:getCompanyBookKeepingProcessList", function(source, companyId)
    local xPlayer = ESX.GetPlayerFromId(source)

    local accountantJob = GetAccountantJob(xPlayer)

    if not accountantJob then
        return {}
    end

    local bookKeepingProcessList = MySQL.query.await(
        'SELECT * FROM visualz_accountant_book_keeping WHERE company_id = ? AND accountant = ? AND completed = 0', {
            companyId, accountantJob
        })

    for i = #bookKeepingProcessList, 1, -1 do
        local accountantName = MySQL.single.await(
            'SELECT `firstname`, `lastname` FROM `users` WHERE `identifier` = ? LIMIT 1', {
                bookKeepingProcessList[i].accountant_identifier
            })

        local created_at_number = tonumber(bookKeepingProcessList[i].created_at)
        local ending_at_number = tonumber(bookKeepingProcessList[i].ending_at)

        if created_at_number and ending_at_number and accountantName then
            local created_at = math.floor(created_at_number) / 1000
            local ending_at = math.floor(ending_at_number) / 1000

            local percentageDifference, timeLeftString = CalculateTimeInfo(created_at, ending_at, os.time())

            bookKeepingProcessList[i].created_at = os.date("%Y-%m-%d %H:%M:%S", math.floor(created_at_number) / 1000)
            bookKeepingProcessList[i].ending_at = os.date("%Y-%m-%d %H:%M:%S", ending_at)
            bookKeepingProcessList[i].percentageDifference = percentageDifference
            bookKeepingProcessList[i].timeLeftString = timeLeftString
            bookKeepingProcessList[i].accountant_name = accountantName.firstname .. ' ' .. accountantName.lastname
        else
            table.remove(bookKeepingProcessList, i)
        end
    end

    return bookKeepingProcessList
end)

lib.callback.register("visualz_accountant:getCompanyBookKeepings", function(source, companyId)
    local xPlayer = ESX.GetPlayerFromId(source)

    local accountantJob = GetAccountantJob(xPlayer)

    if not accountantJob then
        return {}
    end

    local bookKeepingProcessList = MySQL.query.await(
        'SELECT * FROM visualz_accountant_book_keeping WHERE `company_id` = ? AND `accountant` = ? AND completed = 1', {
            companyId, accountantJob
        })

    for i = #bookKeepingProcessList, 1, -1 do
        local accountantName = MySQL.single.await(
            'SELECT `firstname`, `lastname` FROM `users` WHERE `identifier` = ? LIMIT 1', {
                bookKeepingProcessList[i].accountant_identifier
            })

        local created_at_number = tonumber(bookKeepingProcessList[i].created_at)
        local ending_at_number = tonumber(bookKeepingProcessList[i].ending_at)

        if created_at_number and ending_at_number and accountantName then
            local created_at = math.floor(created_at_number) / 1000
            local ending_at = math.floor(ending_at_number) / 1000

            local percentageDifference, _ = CalculateTimeInfo(created_at, ending_at, os.time())

            bookKeepingProcessList[i].created_at = os.date("%Y-%m-%d %H:%M:%S", math.floor(created_at_number) / 1000)
            bookKeepingProcessList[i].ending_at = os.date("%Y-%m-%d %H:%M:%S", ending_at)
            bookKeepingProcessList[i].percentageDifference = percentageDifference
            bookKeepingProcessList[i].accountant_name = accountantName.firstname .. ' ' .. accountantName.lastname
        else
            table.remove(bookKeepingProcessList, i)
        end
    end

    return bookKeepingProcessList
end)

lib.callback.register("visualz_accountant:editCompany", function(source, companyId, companyName, percentage)
    local xPlayer = ESX.GetPlayerFromId(source)

    local accountantJob = GetAccountantJob(xPlayer, "EditCompany")

    if not accountantJob then
        return { type = 'error', description = 'Du har ikke adgang til denne funktion' }
    end

    local companyConfig = nil
    for _, accountant in pairs(Config.Accountants) do
        if accountant.Job == accountantJob then
            companyConfig = accountant
            break
        end
    end

    if not companyConfig then
        return { type = 'error', description = 'Der skete en fejl' }
    end

    local min = companyConfig.Percentage.min
    local max = companyConfig.Percentage.max

    local companyPercentage = tonumber(percentage)
    if not companyPercentage then
        return { type = 'error', description = "Procenten skal være et tal" }
    end
    local parsedCompanyPercentage = ESX.Math.Round(companyPercentage, 0)

    if type(parsedCompanyPercentage) ~= "number" then
        return { type = 'error', description = "Procenten skal være et tal" }
    end

    if parsedCompanyPercentage ~= companyPercentage then
        return { type = 'error', description = "Procenten skal være et helt tal" }
    end

    if parsedCompanyPercentage < min or parsedCompanyPercentage > max then
        return { type = 'error', description = "Procenten skal være mellem " .. min .. " og " .. max .. "%" }
    end

    local doesCompanyExist = MySQL.single.await(
        'SELECT * FROM `visualz_accountant_company` WHERE `accountant` = ? AND id = ? AND deleted = 0 LIMIT 1', {
            accountantJob, companyId
        })

    if not doesCompanyExist then
        return { type = 'error', description = 'Virksomheden findes ikke' }
    end

    local updateCompanyQuery = MySQL.update.await(
        'UPDATE `visualz_accountant_company` SET `name` = ?, `percentage` = ? WHERE `id` = ? AND `accountant` = ?', {
            companyName, parsedCompanyPercentage, companyId, accountantJob
        })

    if not updateCompanyQuery then
        return { type = 'error', description = 'Der skete en fejl' }
    end

    local tPlayerDb = MySQL.single.await("SELECT * FROM `users` WHERE `identifier` = ? LIMIT 1", {
        doesCompanyExist.identifier
    })

    local tPlayerText = ""
    if not tPlayerDb then
        tPlayerText = "Ukendt"
    else
        tPlayerText = tPlayerDb.firstname .. " " .. tPlayerDb.lastname
    end

    local message =
        "**Revisor navn:** " .. xPlayer.getName() .. "\n" ..
        "**Kunde navn:** " .. tPlayerText .. "\n\n" ..

        "**Gamle virksomheds navn:** " .. doesCompanyExist.name .. "\n" ..
        "**Nyt virksomheds navn:** " .. companyName .. "\n\n" ..
        "**Virksomheds CVR:** " .. doesCompanyExist.cvr .. "\n\n" ..
        "**Gamle procent:** " .. ESX.Math.Round(doesCompanyExist.percentage, 0) .. "\n" ..
        "**Ny procent:** " .. parsedCompanyPercentage .. "\n\n" ..

        "**Revisor:** " .. xPlayer.getIdentifier() .. "\n" ..
        "**Kunde:** " .. doesCompanyExist.identifier .. "\n"

    SendLog(Logs["EditCompany"], 2829617, "Rediger virksomhed", message,
        "Visualz Development | Visualz.dk | " .. os.date("%d/%m/%Y %H:%M:%S"))

    return { type = 'success', description = 'Virksomheden er blevet opdateret' }
end)

lib.callback.register("visualz_accountant:deleteCompany", function(source, companyId)
    local xPlayer = ESX.GetPlayerFromId(source)

    local accountantJob = GetAccountantJob(xPlayer, "DeleteCompany")

    if not accountantJob then
        return { type = 'error', description = 'Du har ikke adgang til denne funktion' }
    end

    local doesCompanyExist = MySQL.single.await(
        'SELECT * FROM `visualz_accountant_company` WHERE `id` = ? AND `accountant` = ? AND `deleted` = 0 LIMIT 1', {
            companyId, accountantJob
        })

    if not doesCompanyExist then
        return { type = 'error', description = 'Virksomheden findes ikke' }
    end

    local didCompanyDelete = MySQL.update.await(
        'UPDATE `visualz_accountant_company` SET `deleted` = ? WHERE `id` = ? AND `accountant` = ?', {
            1, companyId, accountantJob
        })

    if not didCompanyDelete then
        return { type = 'error', description = 'Der skete en fejl' }
    end

    local tPlayerDb = MySQL.single.await("SELECT * FROM `users` WHERE `identifier` = ? LIMIT 1", {
        doesCompanyExist.identifier
    })

    local tPlayerText = ""
    if not tPlayerDb then
        tPlayerText = "Ukendt"
    else
        tPlayerText = tPlayerDb.firstname .. " " .. tPlayerDb.lastname
    end

    local message =
        "**Revisor navn:** " .. xPlayer.getName() .. "\n" ..
        "**Kunde navn:** " .. tPlayerText .. "\n\n" ..

        "**Virksomheds navn:** " .. doesCompanyExist.name .. "\n" ..
        "**Virksomheds CVR:** " .. doesCompanyExist.cvr .. "\n" ..
        "**Virksomheds procent:** " .. ESX.Math.Round(doesCompanyExist.percentage, 0) .. "\n\n" ..
        "**Revisor:** " .. xPlayer.getIdentifier() .. "\n" ..
        "**Kunde:** " .. doesCompanyExist.identifier .. "\n"

    SendLog(Logs["DeleteCompany"], 2829617, "Slettet virksomhed", message,
        "Visualz Development | Visualz.dk | " .. os.date("%d/%m/%Y %H:%M:%S"))

    return { type = 'success', description = 'Virksomheden er blevet slettet' }
end)

lib.callback.register("visualz_accountant:payOutBookKeeping", function(source, bookKeepingId)
    local xPlayer = ESX.GetPlayerFromId(source)

    local accountantJob = GetAccountantJob(xPlayer, "PayoutBookKeeping")
    if not accountantJob then
        return { type = 'error', description = 'Du har ikke adgang til denne funktion' }
    end

    local doesCompanyExist = MySQL.single.await(
        'SELECT * FROM `visualz_accountant_company` WHERE `accountant` = ? AND `deleted` = 0 LIMIT 1', {
            accountantJob
        })
    if not doesCompanyExist then
        return { type = 'error', description = 'Virksomheden findes ikke' }
    end

    local companyConfig = nil
    for _, accountant in pairs(Config.Accountants) do
        if accountant.Job == accountantJob then
            companyConfig = accountant
            break
        end
    end

    if not companyConfig then
        return { type = 'error', description = 'Der skete en fejl' }
    end

    local bookKeeping = MySQL.single.await(
        'SELECT * FROM `visualz_accountant_book_keeping` WHERE `id` = ? AND `accountant` = ? AND completed = 0 LIMIT 1',
        {
            bookKeepingId, accountantJob
        })
    if not bookKeeping then
        return { type = 'error', description = 'Bogføringen findes ikke' }
    end

    local created_at_number = tonumber(bookKeeping.created_at)
    local ending_at_number = tonumber(bookKeeping.ending_at)

    if not created_at_number or not ending_at_number then
        return { type = 'error', description = 'Der skete en fejl' }
    end

    local created_at = math.floor(created_at_number) / 1000
    local ending_at = math.floor(ending_at_number) / 1000

    local percentageDifference, _ = CalculateTimeInfo(created_at, ending_at, os.time())

    if percentageDifference < 100 then
        return { type = 'error', description = 'Bogføringen er ikke færdig endnu' }
    end

    local companyOwnerIdentifier = MySQL.single.await(
        'SELECT `identifier` FROM `visualz_accountant_company` WHERE `id` = ? LIMIT 1', {
            bookKeeping.company_id
        })

    if not companyOwnerIdentifier then
        return { type = 'error', description = 'Der skete en fejl' }
    end

    local companyOwner = ESX.GetPlayerFromIdentifier(companyOwnerIdentifier.identifier)
    if not companyOwner then
        return { type = 'error', description = 'Virksomheds ejeren er ikke til rådighed lige nu' }
    end

    local accountantPayout = ESX.Math.Round(bookKeeping.amount_inserted - bookKeeping.amount_receiving, 0)

    TriggerEvent('esx_addonaccount:getSharedAccount', "society_" .. companyConfig.Job, function(account)
        account.addMoney(accountantPayout)
    end)

    local queries = {
        {
            'UPDATE `visualz_accountant_book_keeping` SET `completed` = 1 WHERE `id` = ?',
            {
                bookKeepingId
            },
        },
        {
            'UPDATE `visualz_accountant_company` SET `money_washed` = `money_washed` + ? WHERE `id` = ?',
            {
                bookKeeping.amount_inserted, bookKeeping.company_id
            }
        },
    }

    local didQueriesSucceed = MySQL.transaction.await(queries)
    if not didQueriesSucceed then
        return { type = 'error', description = 'Der skete en fejl' }
    end

    companyOwner.addAccountMoney('bank', bookKeeping.amount_receiving)

    local message =
        "**Revisor navn:** " .. xPlayer.getName() .. "\n" ..
        "**Kunde navn:** " .. companyOwner.getName() .. "\n\n" ..
        "**Virksomheds navn:** " .. doesCompanyExist.name .. "\n" ..
        "**Virksomheds CVR:** " .. doesCompanyExist.cvr .. "\n" ..
        "**Virksomheds procent:** " .. doesCompanyExist.percentage .. "\n\n" ..
        "**Bogføring:** " .. ESX.Math.Round(bookKeeping.amount_inserted, 0) .. "\n" ..
        "**Udbetaling:** " .. ESX.Math.Round(bookKeeping.amount_receiving, 0) .. "\n" ..
        "**Revisor udbetaling:** " .. ESX.Math.Round(accountantPayout, 0) .. "\n\n" ..
        "**Indsat d.** " .. os.date("%d/%m/%Y %H:%M:%S", math.floor(created_at_number) / 1000) .. "\n" ..
        "**Afsluttet d.** " .. os.date("%d/%m/%Y %H:%M:%S", ending_at) .. "\n\n" ..
        "**Revisor:** " .. xPlayer.getIdentifier() .. "\n" ..
        "**Kunde:** " .. doesCompanyExist.identifier .. "\n"

    SendLog(Logs["PayoutBookKeeping"], 2829617, "Udbetal bogføring", message,
        "Visualz Development | Visualz.dk | " .. os.date("%d/%m/%Y %H:%M:%S"))

    TriggerClientEvent("ox_lib:notify", companyOwner.source, {
        description = 'Du har modtaget ' .. bookKeeping.amount_receiving .. ' kr,- fra din bogføring',
        type = 'success',
        icon = 'money-bill',
    })

    return {
        type = 'success',
        description = 'Du har udbetalt ' ..
            bookKeeping.amount_receiving .. ' kr,- til ' .. companyOwner.getName()
    }
end)

lib.callback.register("visualz_accountant:createCompany", function(source, companyOwnerId)
    local xPlayer = ESX.GetPlayerFromId(source)

    local accountantJob = GetAccountantJob(xPlayer, "CreateCompany")
    if not accountantJob then
        return { type = 'error', description = 'Du har ikke adgang til denne funktion' }
    end

    local tPlayer = ESX.GetPlayerFromId(companyOwnerId)
    if not tPlayer then
        return { type = 'error', description = 'Spilleren findes ikke', duration = 10000 }
    end

    if tPlayer.source == xPlayer.source then
        return { type = 'error', description = 'Du kan ikke oprette en virksomhed til dig selv' }
    end

    if companyRequests[tPlayer.source] then
        return { type = 'error', description = 'Spilleren har allerede en forespørgsel' }
    end

    local doesCompanyExist = MySQL.single.await(
        'SELECT `identifier` FROM `visualz_accountant_company` WHERE `identifier` = ? AND `accountant` = ? AND `deleted` = 0 LIMIT 1',
        {
            tPlayer.identifier, accountantJob
        })

    if doesCompanyExist then
        return { type = 'error', description = 'Spilleren har allerede en virksomhed' }
    end

    companyRequests[tPlayer.source] = {
        accountantSource = xPlayer.source,
        timeout = 60,
    }

    TriggerClientEvent("ox_lib:notify", xPlayer.source, {
        id = 'request_data',
        description = 'Du har sendt en forespørgsel til ' .. tPlayer.getName() .. ' om at oprette en virksomhed.',
        icon = 'spinner',
        iconAnimation = "spin",
        duration = 60000,
        position = 'top',
    })

    TriggerClientEvent("ox_lib:notify", tPlayer.source, {
        id = 'request_data',
        description = 'Du er blevet forespurgt om at oprette en virksomhed af ' .. xPlayer.getName() .. '.',
        icon = 'spinner',
        iconAnimation = "spin",
        duration = 60000,
        position = 'top',
    })

    local companyName = lib.callback.await("visualz_accountant:requestCompanyData", tPlayer.source)
    if not companyName then
        companyRequests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'request_data',
            description = 'Du har afvist at oprette en virksomhed',
            type = 'error',
            position = 'top',
        })
        return {
            id = 'request_data',
            description = 'Kunden har afvist at oprette en virksomhed',
            type = 'error',
            position = 'top',
        }
    end

    if companyRequests[tPlayer.source] == nil then
        companyRequests[tPlayer.source] = nil
        return {
            id = 'request_data',
            description = 'Forespørgslen er udløbet',
            type = 'success',
            position = 'top',
        }
    end

    TriggerClientEvent("ox_lib:notify", xPlayer.source, {
        id = 'request_data',
        description = 'Venter på svar fra dig',
        icon = 'spinner',
        iconAnimation = "spin",
        position = 'top',
        duration = 60000,
    })

    TriggerClientEvent("ox_lib:notify", tPlayer.source, {
        id = 'request_data',
        description = 'Venter på svar fra revisoren',
        icon = 'spinner',
        iconAnimation = "spin",
        position = 'top',
        duration = 60000,
    })

    companyRequests[tPlayer.source] = {
        companyName = companyName,
        companyOwner = tPlayer.getName(),
        accountantSource = xPlayer.source,
        timeout = 60,
    }

    local response, percentage = lib.callback.await("visualz_accountant:companyDataResponse", xPlayer.source,
        tPlayer.getName(), companyName)

    if not response then
        companyRequests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'request_data',
            description = 'Din virksomhed er blevet afvist',
            type = 'error',
            position = 'top',
        })
        return {
            id = 'request_data',
            description = 'Du har afvist virksomheden ',
            type = 'error',
            position = 'top',
        }
    end

    if companyRequests[tPlayer.source] == nil then
        return {
            id = 'request_data',
            description = 'Forespørgslen er udløbet',
            type = 'success',
            position = 'top',
        }
    end

    local randomEightDigitNumber = math.random(10000000, 99999999)

    local doesCompanyExistWithCVR = MySQL.single.await(
        'SELECT `identifier` FROM `visualz_accountant_company` WHERE `cvr` = ? AND `deleted` = 0 LIMIT 1', {
            randomEightDigitNumber
        })

    if doesCompanyExistWithCVR then
        companyRequests[tPlayer.source] = nil
        return {
            id = 'request_data',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        }
    end

    local companyConfig = nil
    for _, accountant in pairs(Config.Accountants) do
        if accountant.Job == accountantJob then
            companyConfig = accountant
            break
        end
    end

    if not companyConfig then
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'request_data',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        })
        return { type = 'error', description = 'Der skete en fejl' }
    end

    local min = companyConfig.Percentage.min
    local max = companyConfig.Percentage.max

    local companyPercentage = tonumber(percentage)
    if not companyPercentage then
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'request_data',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        })
        return { type = 'error', description = "Procenten skal være et tal" }
    end
    local parsedCompanyPercentage = ESX.Math.Round(companyPercentage, 0)

    if type(parsedCompanyPercentage) ~= "number" then
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'request_data',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        })
        return { type = 'error', description = "Procenten skal være et tal" }
    end

    if parsedCompanyPercentage < min or companyPercentage > parsedCompanyPercentage then
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'request_data',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        })
        return { type = 'error', description = "Procenten skal være mellem " .. min .. " og " .. max .. "%" }
    end

    local createCompanyQuery = MySQL.insert.await(
        'INSERT INTO `visualz_accountant_company` (identifier, name, cvr, percentage, accountant_identifier, accountant) VALUES (?, ?, ?, ?, ?, ?)',
        {
            tPlayer.identifier, companyName, randomEightDigitNumber, parsedCompanyPercentage, xPlayer.identifier,
            accountantJob
        })

    if not createCompanyQuery then
        companyRequests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'request_data',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        })
        return {
            id = 'request_data',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        }
    end

    companyRequests[tPlayer.source] = nil
    TriggerClientEvent("ox_lib:notify", tPlayer.source, {
        id = 'request_data',
        description = "Din virksomhed er blevet accepteret",
        type = 'success',
        position = 'top',
    })


    local message =
        "**Revisor navn:** " .. xPlayer.getName() .. "\n" ..
        "**Kunde navn:** " .. tPlayer.getName() .. "\n\n" ..

        "**Virksomheds navn:** " .. companyName .. "\n" ..
        "**Virksomheds CVR:** " .. randomEightDigitNumber .. "\n" ..
        "**Virksomheds procent:** " .. parsedCompanyPercentage .. "\n\n" ..
        "**Revisor:** " .. xPlayer.getIdentifier() .. "\n" ..
        "**Kunde:** " .. tPlayer.getIdentifier() .. "\n"

    SendLog(Logs["CreateCompany"], 2829617, "Oprettet virksomhed", message, "Visualz Development | Visualz.dk | " .. os.date("%d/%m/%Y %H:%M:%S"))

    return {
        id = 'request_data',
        description = 'Du har accepteret virksomheden ' .. companyName,
        type = 'success',
        position = 'top',
    }
end)

lib.callback.register("visualz_accountant:createBookKeeping", function(source, companyId)
    local xPlayer = ESX.GetPlayerFromId(source)

    local accountantJob = GetAccountantJob(xPlayer, "CreateBookKeeping")
    if not accountantJob then
        return { type = 'error', description = 'Du har ikke adgang til denne funktion' }
    end

    local tPlayerIdentifier = MySQL.single.await('SELECT `identifier` FROM `visualz_accountant_company` WHERE `id` = ? AND `accountant` = ? AND `deleted` = 0 LIMIT 1', {
        companyId, accountantJob
    })

    if not tPlayerIdentifier then
        return { type = 'error', description = 'Kunden er for langt væk eller findes ikke' }
    end

    local tPlayer = ESX.GetPlayerFromIdentifier(tPlayerIdentifier.identifier)
    if not tPlayer then
        return { type = 'error', description = 'Kunden er for langt væk eller findes ikke' }
    end

    if tPlayer.source == xPlayer.source then
        return { type = 'error', description = 'Du kan ikke bogføre for dig selv' }
    end

    local xPlayerCoords = xPlayer.getCoords(true)
    local tPlayerCoords = tPlayer.getCoords(true)

    local distance = #(xPlayerCoords - tPlayerCoords)

    if distance > 3 then
        return { type = 'error', description = 'Kunden er for langt væk eller findes ikke' }
    end

    if companyRequests[tPlayer.source] then
        return { type = 'error', description = 'Spilleren har allerede en forespørgsel' }
    end

    local doesCompanyExist = MySQL.single.await('SELECT * FROM `visualz_accountant_company` WHERE `identifier` = ? AND `accountant` = ? AND `deleted` = 0 LIMIT 1', {
        tPlayer.identifier, accountantJob
    })

    if not doesCompanyExist then
        return { type = 'error', description = 'Spilleren har ikke en virksomhed' }
    end

    companyRequests[tPlayer.source] = {
        accountantSource = xPlayer.source,
        timeout = 60,
    }

    TriggerClientEvent("ox_lib:notify", xPlayer.source, {
        id = 'request_data',
        description = 'Du har sendt en forespørgsel til ' .. tPlayer.getName() .. ' om at bogføre penge.',
        icon = 'spinner',
        iconAnimation = "spin",
        duration = 60000,
        position = 'top',
    })

    TriggerClientEvent("ox_lib:notify", tPlayer.source, {
        id = 'request_data',
        description = 'Du er blevet forespurgt om at bogføre penge af ' .. xPlayer.getName() .. '.',
        icon = 'spinner',
        iconAnimation = "spin",
        duration = 60000,
        position = 'top',
    })

    local askAgain = false
    :: askAmount ::
    local amountToBookKeep = lib.callback.await("visualz_accountant:requestBookKeepingData", tPlayer.source, doesCompanyExist.name, doesCompanyExist.percentage, tPlayer.getName(), askAgain)
    if not amountToBookKeep then
        companyRequests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'request_data',
            description = 'Du har afvist at bogføre penge',
            type = 'error',
            position = 'top',
        })
        return {
            id = 'request_data',
            description = 'Kunden har afvist at bogføre penge',
            type = 'error',
            position = 'top',
        }
    else
        local companyAmount = tonumber(amountToBookKeep)
        if not companyAmount then
            TriggerClientEvent("ox_lib:notify", tPlayer.source, {
                id = 'request_data',
                description = 'Beløbet skal være et tal',
                type = 'error',
                position = 'top',
            })
            askAgain = true
            goto askAmount
        end
        local parsedCompanyAmount = ESX.Math.Round(companyAmount, 0)

        if not type(parsedCompanyAmount) == "number" then
            TriggerClientEvent("ox_lib:notify", tPlayer.source, {
                id = 'request_data',
                description = 'Beløbet skal være et tal',
                type = 'error',
                position = 'top',
            })
            askAgain = true
            goto askAmount
        end

        if parsedCompanyAmount ~= companyAmount then
            TriggerClientEvent("ox_lib:notify", tPlayer.source, {
                id = 'request_data',
                description = 'Beløbet skal være et helt tal',
                type = 'error',
                position = 'top',
            })
            askAgain = true
            goto askAmount
        end

        if parsedCompanyAmount < 100 then
            TriggerClientEvent("ox_lib:notify", tPlayer.source, {
                type = 'error',
                description = "Du skal bogfører 100 kr,- som minimum"
            })
            askAgain = true
            goto askAmount
        end
    end

    if companyRequests[tPlayer.source] == nil then
        return {
            id = 'request_data',
            description = 'Forespørgslen er udløbet',
            type = 'info',
            position = 'top',
        }
    end

    TriggerClientEvent("ox_lib:notify", xPlayer.source, {
        id = 'request_data',
        description = 'Venter på svar fra dig',
        icon = 'spinner',
        iconAnimation = "spin",
        position = 'top',
        duration = 60000,
    })

    TriggerClientEvent("ox_lib:notify", tPlayer.source, {
        id = 'request_data',
        description = 'Venter på svar fra revisoren',
        icon = 'spinner',
        iconAnimation = "spin",
        position = 'top',
        duration = 60000,
    })

    companyRequests[tPlayer.source] = {
        accountantSource = xPlayer.source,
        timeout = 60,
    }

    local response = lib.callback.await("visualz_accountant:companyBookKeepingResponse", xPlayer.source, tPlayer.getName(), doesCompanyExist.name, amountToBookKeep, doesCompanyExist.percentage)

    if not response then
        companyRequests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'request_data',
            description = 'Din bogføring er blevet afvist',
            type = 'error',
            position = 'top',
        })
        return {
            id = 'request_data',
            description = 'Du har afvist bogføringen',
            type = 'error',
            position = 'top',
        }
    end

    if companyRequests[tPlayer.source] == nil then
        return {
            id = 'request_data',
            description = 'Forespørgslen er udløbet',
            type = 'info',
            position = 'top',
        }
    end

    local companyAmount = tonumber(amountToBookKeep)
    if not companyAmount then
        companyRequests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'request_data',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        })
        return {
            id = 'request_data',
            description = "Beløbet skal være et tal",
            type = 'error',
            position = 'top',
        }
    end

    local parsedCompanyAmount = ESX.Math.Round(companyAmount, 0)
    if not type(parsedCompanyAmount) == "number" then
        companyRequests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'request_data',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        })
        return {
            id = 'request_data',
            description = "Beløbet skal være et tal",
            type = 'error',
            position = 'top',
        }
    end

    if ESX.Math.Round(parsedCompanyAmount, 0) ~= companyAmount then
        companyRequests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'request_data',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        })
        return {
            id = 'request_data',
            description = "Beløbet skal være et helt tal",
            type = 'error',
            position = 'top',
        }
    end

    if parsedCompanyAmount < 100 then
        companyRequests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'request_data',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        })
        return {
            id = 'request_data',
            description = "Du skal bogfører 100 kr,- som minimum",
            type = 'error',
            position = 'top',
        }
    end

    local receivingAmount = ESX.Math.Round((100 - doesCompanyExist.percentage) * parsedCompanyAmount / Config.BookKeepingTime, 0)
    if receivingAmount <= 0 then
        companyRequests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'request_data',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        })
        return {
            id = 'request_data',
            description = "Du kan ikke bogfører med en procentsats på 100",
            type = 'error',
            position = 'top',
        }
    end

    local lastBookKeeping = MySQL.single.await('SELECT `ending_at`, `created_at` FROM `visualz_accountant_book_keeping` WHERE `company_id` = ? AND `accountant` = ? AND completed = 0 ORDER BY `ending_at` DESC LIMIT 1', {
        doesCompanyExist.id, accountantJob
    })

    local ending_at_time

    if not lastBookKeeping then
        ending_at_time = os.time() + ESX.Math.Round(parsedCompanyAmount / Config.BookKeepingTime, 0)
    else
        local currentUnixTime = os.time()
        local startUnixTime = lastBookKeeping.created_at / 1000
        local endUnixTime = lastBookKeeping.ending_at / 1000
        local totalTime = endUnixTime - startUnixTime
        local timeLeft = endUnixTime - currentUnixTime

        if timeLeft < totalTime then
            ending_at_time = os.time() + ESX.Math.Round(parsedCompanyAmount / Config.BookKeepingTime, 0) + timeLeft
        else
            ending_at_time = os.time() + ESX.Math.Round(parsedCompanyAmount / Config.BookKeepingTime, 0)
        end
    end

    local ending_at = os.date("%Y-%m-%d %H:%M:%S", ending_at_time)

    local hasEnoughMoney = tPlayer.getAccount('black_money').money >= parsedCompanyAmount
    if not hasEnoughMoney then
        companyRequests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'request_data',
            description = 'Du har ikke det indtastet kontanter på dig',
            type = 'error',
            position = 'top',
        })
        return {
            id = 'request_data',
            description = 'Kunden har ikke det indtastet kontanter på sig',
            type = 'error',
            position = 'top',
        }
    end

    tPlayer.removeAccountMoney('black_money', parsedCompanyAmount)

    local didBookKeepingProcessInsert = MySQL.insert.await(
        'INSERT INTO `visualz_accountant_book_keeping` (company_id, accountant_identifier, amount_inserted, percentage, amount_receiving, ending_at, accountant) VALUES (?, ?, ?, ?, ?, ?, ?)',
        {
            doesCompanyExist.id, xPlayer.identifier, parsedCompanyAmount, doesCompanyExist.percentage, receivingAmount,
            ending_at, accountantJob
        })

    if not didBookKeepingProcessInsert then
        companyRequests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'request_data',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        })
        return {
            id = 'request_data',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        }
    end

    companyRequests[tPlayer.source] = nil
    TriggerClientEvent("ox_lib:notify", tPlayer.source, {
        id = 'request_data',
        description = "Din bogføring er blevet accepteret",
        type = 'success',
        position = 'top',
    })

    local accountantPayout = ESX.Math.Round(parsedCompanyAmount - receivingAmount, 0)
    local endingFormat = os.date("%d/%m/%Y %H:%M:%S", ending_at_time)

    local message =
        "**Revisor navn:** " .. xPlayer.getName() .. "\n" ..
        "**Kunde navn:** " .. tPlayer.getName() .. "\n\n" ..

        "**Virksomheds navn:** " .. doesCompanyExist.name .. "\n" ..
        "**Virksomheds CVR:** " .. doesCompanyExist.cvr .. "\n" ..
        "**Virksomheds procent:** " .. doesCompanyExist.percentage .. "\n\n" ..
        "**Bogføring:** " .. parsedCompanyAmount .. "\n" ..
        "**Udbetaling:** " .. receivingAmount .. "\n" ..
        "**Revisor udbetaling:** " .. accountantPayout .. "\n\n" ..
        "**Indsat d.** " .. os.date("%d/%m/%Y %H:%M:%S") .. "\n" ..
        "**Slutter d.** " .. endingFormat .. "\n\n" ..

        "**Revisor:** " .. xPlayer.getIdentifier() .. "\n" ..
        "**Kunde:** " .. doesCompanyExist.identifier .. "\n"

    SendLog(Logs["CreateBookKeeping"], 2829617, "Opret bogførsel", message,
        "Visualz Development | Visualz.dk | " .. os.date("%d/%m/%Y %H:%M:%S"))

    return {
        id = 'request_data',
        description = 'Du har accepteret bogføringen',
        type = 'success',
        position = 'top',
    }
end)

function GenerateRandomEightDigitNumber()
    local randomEightDigitNumber = math.random(10000000, 99999999)
    return randomEightDigitNumber
end

function CalculateTimeInfo(startUnixTime, endUnixTime, currentUnixTime)
    local totalTime = endUnixTime - startUnixTime
    local elapsedTime = currentUnixTime - startUnixTime

    if currentUnixTime <= startUnixTime then
        elapsedTime = 0
    elseif currentUnixTime >= endUnixTime then
        elapsedTime = totalTime
    end

    local percentage = (elapsedTime / totalTime) * 100

    local timeLeft = endUnixTime - currentUnixTime
    local days = math.floor(timeLeft / (24 * 60 * 60))
    local hours = math.floor((timeLeft % (24 * 60 * 60)) / (60 * 60))
    local minutes = math.floor((timeLeft % (60 * 60)) / 60)
    local seconds = math.floor(timeLeft % 60)

    local timeLeftString = ""

    if days > 0 then
        timeLeftString = timeLeftString .. days .. " dag" .. (days > 1 and "e" or "") .. (hours > 0 and ", " or "")
    end

    if hours > 0 then
        timeLeftString = timeLeftString .. hours .. " time" .. (hours > 1 and "r" or "") .. (minutes > 0 and ", " or "")
    end

    if minutes > 0 then
        timeLeftString = timeLeftString ..
            minutes .. " minut" .. (minutes > 1 and "ter" or "") .. (seconds > 0 and ", " or "")
    end

    if seconds > 0 then
        timeLeftString = timeLeftString .. seconds .. " sekund" .. (seconds > 1 and "er" or "")
    end

    return percentage, timeLeftString
end

function GetAccountantJob(xPlayer, featureName)
    local accountantJob = nil
    for _, accountant in pairs(Config.Accountants) do
        if featureName then
            for feature, perm in pairs(accountant.BossOnly) do
                if feature == featureName then
                    if perm then
                        if accountant.Job == xPlayer.job.name and xPlayer.job.grade_name == "boss" then
                            accountantJob = accountant.Job
                            break
                        end
                    end
                end
            end
        end

        if accountant.Job == xPlayer.job.name then
            accountantJob = accountant.Job
            break
        end
    end
    return accountantJob
end

function SendLog(WebHook, color, title, message, footer)
    local embedMsg = {
        {
            ["color"] = color,
            ["title"] = title,
            ["description"] = "" .. message .. "",
            ["footer"] = {
                ["text"] = footer,
            },
        }
    }
    PerformHttpRequest(WebHook, function(err, text, headers) end, 'POST',
        json.encode({
            username = Config.whName,
            avatar_url = Config.whLogo,
            embeds = embedMsg
        }),
        { ['Content-Type'] = 'application/json' })
end
