# Function to extract method signatures along with their start and end lines
print("Hello, world!")
def extract_method_signatures(code, methods_to_search):
    method_matches = re.finditer(r"(?P<signature>((@isTest\s+)?(public|private|protected|global)?\s+(static)?\s*([\w.<>]+)\s+(\w+)\s*\(.*\)\s*\{))", code)
    extracted_methods = []
    brackets_count = 0

    print("Debug: Starting method extraction")  # Debug line

    for match in method_matches:
        print(f"Debug: Found match: {match.group('signature')}")  # Debug line

        method_info = {}
        start_line = code[:match.start()].count('\n') + 1
        method_signature = match.group("signature").strip()

        method_info["signature"] = method_signature
        method_info["starts_at_line"] = start_line
        method_info["ends_at_line"] = None  # Placeholder, will update later

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

    print(f"Debug: Extracted methods: {extracted_methods}")  # Debug line

    return extracted_methods
