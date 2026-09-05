# Deliberately limited canonical TOML, not a general TOML parser.
# Strings use the common single-line basic-string / JSON escape subset.
def trim: gsub("^\\s+|\\s+$"; "");
def safe_id: test("^[A-Za-z0-9_-]+(?:[.][A-Za-z0-9_-]+)*$");
def issue($message):
    .errors += ["Line \(.line + 1): \($message)"] |
    if .current >= 0 then .sections[.current].errors += [$message] else . end;
def finish:
    if .current >= 0 then .sections[.current].end = .line else . end;
def path($base):
    if startswith("@CLAVIS_GENERATED_HOME@/") and $origin == "builtin" then
        $ENV.CLAVIS_GENERATED_HOME + ltrimstr("@CLAVIS_GENERATED_HOME@")
    elif . == "~" or . == "$HOME" then $ENV.HOME
    elif startswith("~/") then $ENV.HOME + .[1:]
    elif startswith("$HOME/") then $ENV.HOME + .[5:]
    else . end |
    if test("[$`\u0000-\u001f\u007f]") or startswith("~") or . == "" then ""
    elif startswith("/") then .
    elif $base != "" then $base + "/" + .
    else "" end;
split("\n") as $lines |
reduce range(0; $lines | length) as $i (
    {sections: [], errors: [], current: -1, context: "", line: 0};
    .line = $i | ($lines[$i] | trim) as $s |
    if $s == "" or ($s | startswith("#")) then .
    elif ($s | test("^\\[templates\\.(?:[A-Za-z0-9_-]+|\"[A-Za-z0-9._-]+\")\\]\\s*(?:#.*)?$")) then
        finish |
        ($s | capture("^\\[templates\\.(?<id>[A-Za-z0-9_-]+|\"[A-Za-z0-9._-]+\")\\]").id | gsub("\""; "")) as $id |
        .sections += [{id: $id, start: $i, end: ($lines | length), fields: {}, errors: []}] |
        .current = (.sections | length) - 1 | .context = "template" |
        if ($id | safe_id) then . else issue("Invalid template ID") end
    elif ($s | startswith("[")) then
        finish | .current = -1 |
        if $s == "[config]" and $origin == "builtin" then .context = "config"
        else .context = "unsupported" | issue("Unsupported section syntax: " + $s) end
    elif .context == "config" and $s == "version_check = false" then .
    elif .context == "template" then
        (try ($s | [capture("^(?<key>input_path|output_path|post_hook)\\s*=\\s*(?<value>\"(?:[^\"\\\\\\x00-\\x1f]|\\\\[\"\\\\bfnrt]|\\\\u[0-9A-Fa-f]{4})*\")\\s*(?:#.*)?$")] | .[0]) catch null) as $field |
        if $field == null then issue("Unsupported template field or string syntax")
        elif (.sections[.current].fields | has($field.key)) then issue("Duplicate field: " + $field.key)
        else (try ($field.value | fromjson) catch null) as $value |
            if $value == null then issue("Invalid string")
            else .sections[.current].fields[$field.key] = $value end
        end
    else issue("Unsupported registry syntax") end
) |
.sections as $all |
.sections |= map(
    . as $entry |
    .origin = $origin | .title = .id | .icon = "palette" |
    .inputPath = ((.fields.input_path // "") | path($base)) |
    .outputPath = ((.fields.output_path // "") | path("")) |
    .postHook = (.fields.post_hook // "") |
    .hasPostHook = (.postHook != "") |
    if ([$all[] | select(.id == $entry.id)] | length) > 1 then .errors += ["Duplicate template ID"] else . end |
    if .inputPath == "" then .errors += ["Invalid input path"] else . end |
    if .outputPath == "" or (.outputPath | endswith("/")) then .errors += ["Use an absolute output file path, ~/ or $HOME/"] else . end |
    .valid = (.errors | length == 0) | .error = (.errors | unique | join("; "))
) | {sections, errors}
