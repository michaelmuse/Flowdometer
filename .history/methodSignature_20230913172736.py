import re
import json

# Function to read the Apex class file
def read_apex_class_file(file_path):
    with open(file_path, 'r') as file:
        return file.read()

# Function to extract method signatures along with their start and end lines
def extract_method_signatures(code, methods_to_search):
    method_matches = re.finditer(r"(?P<signature>((@isTest\s+)?(public|private|protected|global)?\s+(static)?\s*(\w+)\s+(\w+)\s*\(.*\)\s*\{))", code)
    extracted_methods = []
    brackets_count = 0
    for match in method_matches:
        start_line = code[:match.start()].count('\n') + 1
        method_signature = match.group("signature").strip()
        code_subset = code[match.start():]
        lines_with_methods = {method: [] for method in methods_to_search}  # Initialize with methods to search for

        for i, char in enumerate(code_subset):
            if char == '{':
                brackets_count += 1
            elif char == '}':
                brackets_count -= 1
                if brackets_count == 0:
                    end_line = start_line + code_subset[:i].count('\n')
                    method_code = code_subset[:i]
                    for line_num, line in enumerate(method_code.split('\n'), start=start_line):
                        for method in methods_to_search:
                            if method in line:
                                lines_with_methods[method].append(line_num)
                    extracted_methods.append({
                        "signature": method_signature,
                        "start_line": start_line,
                        "end_line": end_line,
                        "lines_with_methods": lines_with_methods
                    })
                    break

    return extracted_methods

# List of methods to search for within each method body
methods_to_search = ['preparingResponse', 'parseRecordsToFlow', 'getQueryModifiers', 'getLatestHistoryValues', 'getStringNotNull', 'isCustomObject']

# Provide the path to the Apex test class
apex_test_class_path = "F:\\Muse Operations Drive\\Projects\\Flowdometer\\force-app\\main\\default\\classes\\ListenerFlowController.cls"

# Read the Apex class file content
apex_test_class_code = read_apex_class_file(apex_test_class_path)

# Extract method signatures and their corresponding lines
extracted_methods_info = extract_method_signatures(apex_test_class_code, methods_to_search)

# Prettify the output using JSON formatting
json_output = json.dumps(extracted_methods_info, indent=4)
print(json_output)
