import re
import json

def read_apex_class_file(file_path):
    with open(file_path, 'r') as file:
        return file.read()
    
def extract_method_signatures(code, methods_to_search):
    # Regex updated to include return type capture group named "return_type"
    method_matches = re.finditer(r"(?P<signature>((@isTest\s+)?(public|private|protected|global)?\s+(static)?\s*(?P<return_type>[\w.<>]+)\s+([a-zA-Z_]\w+)\s*\(.*\)\s*\{))", code)
    extracted_methods = []
    
    for match in method_matches:
        brackets_count = 0
        method_info = {}
        start_line = code[:match.start()].count('\n') + 1
        method_signature = match.group("signature").strip()

        # Added return type
        method_info["return_type"] = match.group("return_type").strip()
        method_info["signature"] = method_signature
        # Changed line range formatting
        method_info["lines"] = f"{start_line}-"
        method_info["ends_at_line"] = None  # Placeholder, will update later

        code_subset = code[match.start():]
        lines_with_methods = {}
        variables_in_scope = []  # Added variable list

        for i, char in enumerate(code_subset):
            if char == '{':
                brackets_count += 1
            elif char == '}':
                brackets_count -= 1
                if brackets_count == 0:
                    end_line = start_line + code_subset[:i].count('\n')
                    # Updated line range formatting
                    method_info["lines"] = f"{start_line}-{end_line}"
                    method_code = code_subset[:i]

                    # Added variable extraction
                    var_matches = re.findall(r"(?:[\w.<>]+)\s+([\w]+)\s*=", method_code)
                    variables_in_scope.extend(var_matches)
                    
                    for line_num, line in enumerate(method_code.split('\n'), start=start_line):
                        for method in methods_to_search:
                            if f"{method}(" in line:
                                if method not in lines_with_methods:
                                    lines_with_methods[method] = []
                                lines_with_methods[method].append(line_num)

                    if lines_with_methods:
                        method_info["called_methods"] = lines_with_methods
                    
                    if variables_in_scope:
                        method_info["variables_in_scope"] = variables_in_scope  # Added variables to JSON

                    extracted_methods.append(method_info)
                    break
    return extracted_methods

# List of methods to search for within each method body
methods_to_search = ['preparingResponse', 'parseRecordsToFlow', 'getQueryModifiers', 'getLatestHistoryValues', 'runTest', 'buildQuery', 'getQueryModifiers']

# List of Apex test class paths
apex_test_class_paths = [
    "F:\\Muse Operations Drive\\Projects\\Flowdometer\\force-app\\main\\default\\classes\\ListenerFlowController.cls",
    "F:\\Muse Operations Drive\\Projects\\Flowdometer\\force-app\\main\\default\\classes\\ListenerFlowControllerTest.cls",
    "F:\\Muse Operations Drive\\Projects\\Flowdometer\\force-app\\main\\default\\classes\\TestDataFactory.cls"
]

final_output = {}

# Loop over each file path
for path in apex_test_class_paths:
    apex_test_class_code = read_apex_class_file(path)
    extracted_methods_info = extract_method_signatures(apex_test_class_code, methods_to_search)
    final_output[path] = extracted_methods_info

# Save to JSON file
with open('FlowdometerApexMethodSignatures.json', 'w') as json_file:
    json.dump(final_output, json_file, indent=2)

