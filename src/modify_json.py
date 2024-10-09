import json
import sys
import argparse

def modify_json(item, additional):
    # Ejemplo de manipulación: Añadir "_modified" a DisplayName
    item['DisplayName'] += "_modified"
    # Añadir información adicional del segundo JSON
    item.update(additional)
    return item

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Process some JSON.')
    parser.add_argument('-grupoInput', type=str, required=True, help='JSON input string')
    parser.add_argument('-currentOLPermissions', type=str, required=True, help='Additional JSON input string')
    args = parser.parse_args()

    # Cargar los datos JSON de los argumentos de entrada
    item = json.loads(args.jsonInput)
    additional = json.loads(args.jsonAdditional)

    # Modificar los datos JSON
    modified_item = modify_json(item, additional)

    # Imprimir los datos JSON modificados
    print(json.dumps(modified_item))
