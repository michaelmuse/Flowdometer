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
                    method_info["ends_at_line"] = end_line
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
