import xml.etree.ElementTree as ET
import json
import os

def parse_xml_to_json(xml_file):
    tree = ET.parse(xml_file)
    root = tree.getroot()

    field_data = {}
    for elem in root:
        tag = elem.tag.split('}')[-1]  # Remove namespace
        value = elem.text
        if tag not in ['redundantTag1', 'redundantTag2']:
            field_data[tag] = value

    return field_data

if __name__ == "__main__":
    json_output = {}
    for dirpath, _, filenames in os.walk("force-app/main/default/objects"):
        dir_name = os.path.basename(dirpath)
        parent_dir_name = os.path.basename(os.path.dirname(dirpath))

        if parent_dir_name in ['Listener__c', 'Flow__c', 'Step__c'] and dir_name == 'fields':
            json_output[parent_dir_name] = {}
            for filename in filenames:
                if filename.endswith('.field-meta.xml'):
                    filepath = os.path.join(dirpath, filename)

                    field_name = os.path.splitext(filename)[0].replace(".field-meta", "")
                    json_output[parent_dir_name][field_name] = parse_xml_to_json(filepath)

    # NOTE: write to a distinct generated filename so this raw auto-parse never
    # clobbers the hand-curated reviewer doc FlowdometerObjectSchema.json (which is
    # linked from FlowdometerOverview.txt for Security Review).
    with open("FlowdometerObjectSchema.generated.json", "w") as f:
        json.dump(json_output, f, indent=4)
