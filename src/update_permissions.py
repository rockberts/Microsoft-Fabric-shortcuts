import json

class Constantes:
    KINDPOLICY   = "Policy"
    EFFECTPERMIT = "Permit"
    ATTRIBUTENAMEPATH = "Path"
    ATTRIBUTEVALUEINCLUDEINREAD = "Read"
    ATTRIBUTENAMEACTION = "Action"

class Item:
    def __init__(self, name, kind, decisionRules, members):
        self.name = name
        self.kind = kind
        self.decisionRules = decisionRules
        self.members = members

    def to_dict(self):
        return {
            "name": self.name,
            "kind": self.kind,
            "decisionRules": self.decisionRules,
            "members": self.members
        }
    

class Members:
    def __init__(self, microsoftEntraMembers):
        self.microsoftEntraMembers = microsoftEntraMembers
        
    def to_dict(self):
        return {
            "microsoftEntraMembers": self.microsoftEntraMembers
         }
    
class DecisionRules:
    def __init__(self, effect, permission):
        self.effect = effect
        self.permission = permission
        
    def to_dict(self):
        return {
            "effect": self.effect,
            "permission": self.permission
        }

class Permission:
    def __init__(self, attributeName, attributeValueIncludeIn):
        self.attributeName = attributeName
        self.attributeValueIncludeIn = attributeValueIncludeIn
        
    def to_dict(self):
        return {
            "attributeName": self.attributeName,
            "attributeValueIncludeIn": self.attributeValueIncludeIn
        }

class JSONManager:
    def __init__(self, json_data):
        self.data = json.loads(json_data)

    def update_item(self, roleName, updated_item):
        for i, item in enumerate(self.data['value']):
            if item['name'] == roleName:

                for rule in item['decisionRules']:
                    for permission in rule['permission']:
                        if permission['attributeName'] == "Path":
                            currentContainers =  permission['attributeValueIncludedIn']
                            containerToInclude = updated_item.decisionRules
                            for permission in containerToInclude['permission']:
                                if permission['attributeName'] == 'Path':
                                    attribute_values = permission['attributeValueIncludeIn']
                            if attribute_values[0] not in currentContainers:
                                currentContainers.append(attribute_values[0])
                
                permisosActuales = item['members']['microsoftEntraMembers']
                nuevoPermisos = updated_item.members['microsoftEntraMembers']
                for permiso in nuevoPermisos:
                    if permiso not in permisosActuales:
                        permisosActuales.append(permiso)
                break
        else:
            self.data['value'].append(updated_item.to_dict())

    def to_json(self):
        return json.dumps(self.data, indent=4)


def create_update_permission(jsonCurrentPermission, roleName, permisos, containerPath):

    manager = JSONManager(jsonCurrentPermission)

    entraMembers = []
               
    for permiso in permisos:
        entraMembers.append(permiso)

    members = Members(
        microsoftEntraMembers= entraMembers
    )


    attributeNameAction = Permission(
        attributeName           = Constantes.ATTRIBUTENAMEACTION,
        attributeValueIncludeIn = Constantes.ATTRIBUTEVALUEINCLUDEINREAD
    )

    container = []
    container.append(containerPath)

    attributeNamePath = Permission(
        attributeName = Constantes.ATTRIBUTENAMEPATH,
        attributeValueIncludeIn= container
    )


    decisionRuleObject = DecisionRules(
        effect     = Constantes.EFFECTPERMIT,
        permission = [attributeNameAction.to_dict(),attributeNamePath.to_dict()]
    )

    updated_item = Item(
        name          = roleName,
        kind          = Constantes.KINDPOLICY,
        decisionRules = decisionRuleObject.to_dict(),
        members       = members.to_dict()
    )

    manager.update_item(roleName, updated_item)
    print(manager.to_json())

permisos=[{"tenantId":tenantID,"objectId":ObjectId}]
displayName = DisplayName
nombredelshortcut = ContainerName
jsonCurrentPermission = '''
            {
            "value": [
                {
                "name": "rolegrupodos",
                "kind": "Policy",
                "decisionRules": [
                    {
                    "effect": "Permit",
                    "permission": [
                        {
                        "attributeName": "Path",
                        "attributeValueIncludedIn": [
                            "/Files/folder_grupo_uno",
                            "/Files/folder_grupo_uno_a"
                        ]
                        },
                        {
                        "attributeName": "Action",
                        "attributeValueIncludedIn": [
                            "Read"
                        ]
                        }
                    ]
                    }
                ],
                "members": {
                    "microsoftEntraMembers": [
                    {
                        "tenantId": "xxxrrrr",
                        "objectId": "wwaaaaa"
                    },
                    {
                        "tenantId": "xxxrrrr",
                        "objectId": "gbvvccccc"
                    }
                    ]
                }
                }
            ]
            }
        '''

create_update_permission(jsonCurrentPermission, displayName, permisos, nombredelshortcut)



