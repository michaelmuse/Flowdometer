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
                    # Find lines calling the methods within this method
                    method_code = code_subset[:i]
                    for line_num, line in enumerate(method_code.split('\n'), start=start_line):
                        for method in methods_to_search:
                            if method in line:
                                lines_with_methods[method].append(line_num)
                    extracted_methods.append({
                        "signature": method_signature,
                        "start_line": start_line,
                        "end_line": end_line,
                        "lines_with_methods": lines_with_methods  # Add the line numbers here
                    })
                    break
    return extracted_methods

# List of methods to search for within each method body
methods_to_search = ['preparingResponse', 'parseRecordsToFlow', 'getQueryModifiers', 'getLatestHistoryValues', 'getStringNotNull', 'isCustomObject']


# Read the Apex class file content
apex_test_class_code = read_apex_class_file(apex_test_class_path)

# Extract method signatures and their corresponding lines
extracted_methods_info = extract_method_signatures(apex_test_class_code, methods_to_search)
print(extracted_methods_info)
