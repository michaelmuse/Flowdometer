import re
import json

def read_apex_class_file(file_path):
    with open(file_path, 'r') as file:
        return file.read()
    
def extract_method_signatures(code, methods_to_search):
    method_matches = re.finditer(r"(?P<signature>((@isTest\s+)?(public|private|protected|global)\s+(static)?\s*(?P<return_type>[\w.<>]+)\s+(?P<return_var>[a-zA-Z_]\w+)\s*\(.*\)\s*\{))", code)
    extracted_methods = []
    
    for match in method_matches:
        brackets_count = 0
        method_info = {}
        start_line = code[:match.start()].count('\n') + 1
        method_signature = match.group("signature").strip()

        method_info["signature"] = method_signature
        method_info["lines"] = f"{start_line}-"
        method_info["variables_in_scope"] = []
        method_info["called_methods"] = {}
        method_info["return_type"] = match.group("return_type").strip()

        lines_with_methods = {}
        variables_in_scope = []

        for i, char in enumerate(code[match.start():]):
            if char == '{':
                brackets_count += 1
            elif char == '}':
                brackets_count -= 1
                if brackets_count == 0:
                    end_line = start_line + code[match.start():match.start()+i].count('\n')
                    method_info["lines"] = f"{start_line}-{end_line}"
                    method_code = code[match.start():match.start()+i]

                    var_matches = re.findall(r"(?:[\w.<>]+)\s+([\w]+)\s*=", method_code)
                    variables_in_scope.extend(var_matches)
                    
                    for line_num, line in enumerate(method_code.split('\n'), start=start_line):
                        for method in methods_to_search:
                            if f"{method}(" in line:
                                if method not in lines_with_methods:
                                    lines_with_methods[method] = []
                                lines_with_methods[method].append(line_num)

                    if variables_in_scope:
                        method_info["variables_in_scope"] = variables_in_scope
                    if lines_with_methods:
                        method_info["called_methods"] = lines_with_methods

                    # Add the return information
                    return_type = match.group("return_type")
                    return_var = match.group("return_var")
                    if return_type and return_var:
                        method_info["return"] = f"{return_type} {return_var}"
           
                    extracted_methods.append(method_info.copy())
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
    # return extracted_methods