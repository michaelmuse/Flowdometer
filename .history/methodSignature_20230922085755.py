import re
import json

# Function to read the Apex class file
def read_apex_class_file(file_path):
    with open(file_path, 'r') as file:
        return file.read()

# Function to extract method signatures along with their start and end lines
def extract_method_signatures(code, methods_to_search):
    method_matches = re.finditer(r"(?P<signature>((@isTest\s+)?(public|private|protected|global)?\s+(static)?\s*([\w.<>]+)\s+(\w+)\s*\(.*\)\s*\{))", code)
    extracted_methods = []
    brackets_count = 0

    for match in method_matches:
        method_info = {}
        start_line = code[:match.start()].count('\n') + 1
        method_signature = match.group("signature").strip()
        
        method_info["start"] = start_line
        method_info["signature"] = method_signature
        method_info["end"] = None  # Placeholder, will update later

        code_subset = code[match.start():]
        lines_with_methods = {}

        for i, char in enumerate(code_subset):
            if char == '{':
                brackets_count += 1
            elif char == '}':
                brackets_count -= 1
                if brackets_count == 0:
                    end_line = start_line + code_subset[:i].count('\n')
                    method_info["end"] = end_line
                    method_code = code_subset[:i]

                    for line_num, line in enumerate(method_code.split('\n'), start=start_line):
                        for method in methods_to_search:
                            if f"{method}(" in line:  # Ensuring we're looking at a method call
                                if method not in lines_with_methods:
                                    lines_with_methods[method] = []
                                lines_with_methods[method].append(line_num)

                    # Only add the 'called_methods' field if there are called methods
                    if lines_with_methods:
                        method_info["called_methods"] = lines_with_methods

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
    # Read the Apex class file content
    apex_test_class_code = read_apex_class_file(path)

    # Extract method signatures and their corresponding lines
    extracted_methods_info = extract_method_signatures(apex_test_class_code, methods_to_search)

    # Add to final output
    final_output[path] = extracted_methods_info

# Prettify the output using JSON formatting
json_output = json.dumps(final_output, indent=4)
print(json_output)
