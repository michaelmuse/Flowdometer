import re

# Function to read the Apex class file
def read_apex_class_file(file_path):
    with open(file_path, 'r') as file:
        return file.read()

# Function to extract method signatures along with their start and end lines
def extract_method_signatures(code):
    method_matches = re.finditer(r"(?P<signature>((@isTest\s+)?(public|private|protected|global)?\s+(static)?\s*(\w+)\s+(\w+)\s*\(.*\)\s*\{))", code)
    extracted_methods = []
    brackets_count = 0
    for match in method_matches:
        start_line = code[:match.start()].count('\n') + 1
        method_signature = match.group("signature").strip()
        code_subset = code[match.start():]
        create_listener_lines = []  # To store lines where createListenerConfig is called
        for i, char in enumerate(code_subset):
            if char == '{':
                brackets_count += 1
            elif char == '}':
                brackets_count -= 1
                if brackets_count == 0:
                    end_line = start_line + code_subset[:i].count('\n')
                    # Find lines calling createListenerConfig within this method
                    method_code = code_subset[:i]
                    for line_num, line in enumerate(method_code.split('\n'), start=start_line):
                        if 'createListenerConfig' in line:
                            create_listener_lines.append(line_num)
                    extracted_methods.append({
                        "signature": method_signature,
                        "start_line": start_line,
                        "end_line": end_line,
                        "create_listener_lines": create_listener_lines  # Add the line numbers here
                    })
                    break
    return extracted_methods

# Provide the path to the Apex test class
apex_test_class_path = "F:\\Muse Operations Drive\\Projects\\Flowdometer\\force-app\\main\\default\\classes\\ListenerFlowControllerTest.cls"

# Read the Apex class file content
apex_test_class_code = read_apex_class_file(apex_test_class_path)

# Extract method signatures and their corresponding lines
extracted_methods_info = extract_method_signatures(apex_test_class_code)
print(extracted_methods_info)
