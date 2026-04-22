function meta = ReadMeta(metaFile)
    lines = splitlines(fileread(metaFile));
    meta = struct();
    for i = 1:length(lines)
        line = strtrim(lines{i});
        if contains(line, '=')
            [k, v] = strtok(line, '=');
            k = matlab.lang.makeValidName(strtrim(k));  % sanitize key
            meta.(k) = strtrim(v(2:end));
        end
    end
end