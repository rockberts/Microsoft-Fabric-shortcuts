
# Configuración de preferencias de error y verbose
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Función para logging
function Write-Log {
    param([string]$Message)
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
}

# Definición de variables
$tenantId = ""
$csvFilePath = "Configuracion.csv"
$workspaceId = ""
$tokenFabric = ""
$resourceGroupName = ""
$storageAccountName = ""
$containerName = ""
$subscriptionId = ""
$rollookup = "Storage Blob Data Reader"

try {
    Write-Log "Iniciando script"

    # Verificar y establecer el contexto de Azure
    Write-Log "Estableciendo contexto de Azure"
    $context = Set-AzContext -SubscriptionId $subscriptionId -ErrorAction Stop
    Write-Log "Contexto establecido: $($context.Subscription.Name)"

    # Verificar existencia del grupo de recursos
    if (Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue) {
        Write-Log "Grupo de recursos $resourceGroupName existe"
    } else {
        throw "Grupo de recursos $resourceGroupName no existe"
    }

    # Verificar existencia de la cuenta de almacenamiento
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -ErrorAction SilentlyContinue
    if ($storageAccount) {
        Write-Log "Cuenta de almacenamiento $storageAccountName existe"
    } else {
        throw "Cuenta de almacenamiento $storageAccountName no existe"
    }

    # Verificar existencia del contenedor
    $ctx = $storageAccount.Context
    if (Get-AzStorageContainer -Name $containerName -Context $ctx -ErrorAction SilentlyContinue) {
        Write-Log "Contenedor $containerName existe"
    } else {
        throw "Contenedor $containerName no existe"
    }

    # Leer el contenido del archivo CSV
    Write-Log "Leyendo archivo CSV: $csvFilePath"
    $csvContent = Import-Csv -Path $csvFilePath -ErrorAction Stop
    Write-Log "CSV leído exitosamente"

    # Iterar sobre cada fila del archivo CSV
    foreach ($row in $csvContent) {
        Write-Log "Procesando fila para: $($row.containerName)"

        $url = "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/items/$($row.lakehouseId)/shortcuts"
        
        # Construir el scope
        $scope = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/blobServices/default/containers/$containerName"
        Write-Log "Scope construido: $scope"

        # Obtener asignaciones de roles
        try {
            Write-Log "Obteniendo asignaciones de roles para el scope"
            $roleAssignments = Get-AzRoleAssignment -Scope $scope -ErrorAction Stop
            Write-Log "Asignaciones de roles obtenidas exitosamente. Total: $($roleAssignments)"
        } catch {
            Write-Log "Error al obtener asignaciones de roles: $_"
            Write-Log "Intentando obtener asignaciones a nivel de cuenta de almacenamiento"
            $storageAccountScope = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName"
            $roleAssignments = Get-AzRoleAssignment -Scope $storageAccountScope -ErrorAction Stop
            Write-Log "Asignaciones de roles obtenidas a nivel de cuenta de almacenamiento. Total: $($roleAssignments.Count)"
        }

        $filteredAssignments = $roleAssignments | Where-Object { 
            $_.RoleDefinitionName -eq $rollookup #-and $_.ObjectType -eq "Group" 
        }
        Write-Log "Asignaciones filtradas: $($filteredAssignments)"

        $grupos = $filteredAssignments | ForEach-Object {
            [PSCustomObject]@{
                DisplayName = $_.DisplayName
                ObjectId = $_.ObjectId
                ContainerName = $containerName
            }
        } | ConvertTo-Json
        Write-Log "Grupos procesados: $grupos"

        $headers = @{
            "Authorization" = "Bearer $tokenFabric"
            "Content-Type" = "application/json"
        }

        $loc_storage_input = "https://$($row.storageAccountName).dfs.core.windows.net"
        Write-Log "URL de almacenamiento: $loc_storage_input"

        $body = @{
            path      = "Files"
            name      = $($row.containerName)
            target = @{
                type = "AdlsGen2"
                adlsGen2 = @{
                    connectionId = $($row.connectionId)
                    location = $loc_storage_input
                    subpath = $($row.containerName)
                }
            }
        }

        $jsonBody = $body | ConvertTo-Json
        Write-Log "Cuerpo de la solicitud preparado"

        Write-Log "Enviando solicitud a Fabric API"
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $Headers -Body $jsonBody -ErrorAction Stop
        Write-Log "Respuesta recibida de Fabric API: $($response | ConvertTo-Json -Depth 3)"

        #Actualizar permisos Onelake
        #Obtener permisos actuales.
        

        $gruposString = $grupos | ConvertFrom-Json
        foreach ($item in $gruposString) {
            $url = "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/items/$($row.lakehouseId)/dataAccessRoles"
            $currentOneLakePermissions = Invoke-RestMethod -Uri $url -Method Get -Headers $Headers -ErrorAction Stop
            $currentOneLakePermissionsJ = $currentOneLakePermissions | ConvertTo-Json -Compress
            Write-Log "Respuesta recibida de Fabric Permisos API: $($currentOneLakePermissions | ConvertTo-Json -Depth 3)"    
            $grupoItem = $item | ConvertTo-Json -Compress
            $jsonOutput = python .\modify_json.py -grupoInput $grupoItem -currentOLPermissions $currentOneLakePermissionsJ
            $modifiedItem = $jsonOutput | ConvertFrom-Json
            Write-Log "Respuesta recibida de pythom modif: $($modifiedItem | ConvertTo-Json -Depth 3)"
            #Write-Output $modifiedItem
        }

    }

    Write-Log "Procesamiento de CSV completado"

} catch {
    Write-Log "Error general en el script: $_"
    Write-Log "Detalles del error:"
    Write-Log $_.Exception.Message
    Write-Log "StackTrace:"
    Write-Log $_.Exception.StackTrace
    if ($_.Exception.InnerException) {
        Write-Log "Excepción interna:"
        Write-Log $_.Exception.InnerException.Message
    }
    Write-Log "Contexto actual de Azure:"
    Get-AzContext | Format-List | Out-String | Write-Log
    throw
} finally {
    Write-Log "Finalizando script"
}
