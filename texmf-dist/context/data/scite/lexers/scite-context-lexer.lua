local info = {
    version   = 1.002,
    comment   = "basics for scintilla lpeg lexer for context/metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    comment   = "contains copyrighted code from mitchell.att.foicica.com",

}

-- The fold and lex functions are copied and patched from original code by Mitchell (see
-- lexer.lua). All errors are mine.
--
-- I've considered making a whole copy and patch the other functions too as we need
-- an extra nesting model. However, I don't want to maintain too much. An unfortunate
-- change in 3.03 is that no longer a script can be specified. This means that instead
-- of loading the extensions via the properties file, we now need to load them in our
-- own lexers, unless of course we replace lexer.lua completely (which adds another
-- installation issue).
--
-- Another change has been that _LEXERHOME is no longer available. It looks like more and
-- more functionality gets dropped so maybe at some point we need to ship our own dll/so
-- files. For instance, I'd like to have access to the current filename and other scite
-- properties. For instance, we could cache some info with each file, if only we had
-- knowledge of what file we're dealing with.
--
-- For huge files folding can be pretty slow and I do have some large ones that I keep
-- open all the time. Loading is normally no ussue, unless one has remembered the status
-- and the cursor is at the last line of a 200K line file. Optimizing the fold function
-- brought down loading of char-def.lua from 14 sec => 8 sec. Replacing the word_match
-- function and optimizing the lex function gained another 2+ seconds. A 6 second load
-- is quite ok for me.
--
-- When the lexer path is copied to the textadept lexer path, and the theme definition to
-- theme path (as lexer.lua), the lexer works there as well. When I have time and motive
-- I will make a proper setup file to tune the look and feel a bit and associate suffixes
-- with the context lexer. The textadept editor has a nice style tracing option but lacks
-- the tabs for selecting files that scite has. It also has no integrated run that pipes
-- to the log pane (I wonder if it could borrow code from the console2 project). Interesting
-- is that the jit version of textadept crashes on lexing large files (and does not feel
-- faster either).
--
-- Function load(lexer_name) starts with _M.WHITESPACE = lexer_name..'_whitespace' which
-- means that we need to have it frozen at the moment we load another lexer. Because spacing
-- is used to revert to a parent lexer we need to make sure that we load children as late
-- as possible in order not to get the wrong whitespace trigger. This took me quite a while
-- to figure out (not being that familiar with the internals). The lex and fold functions
-- have been optimized. It is a pitty that there is no proper print available. Another thing
-- needed is a default style in ourown theme style definition, as otherwise we get wrong
-- nested lexers, especially if they are larger than a view. This is the hardest part of
-- getting things right.
--
-- Eventually it might be safer to copy the other methods from lexer.lua here as well so
-- that we have no dependencies, apart from the c library (for which at some point the api
-- will be stable I guess).
--
-- It's a pitty that there is no scintillua library for the OSX version of scite. Even
-- better would be to have the scintillua library as integral part of scite as that way I
-- could use OSX alongside windows and linux (depending on needs). Also nice would be to
-- have a proper interface to scite then because currently the lexer is rather isolated and the
-- lua version does not provide all standard libraries. It would also be good to have lpeg
-- support in the regular scite lua extension (currently you need to pick it up from someplace
-- else).

local lpeg = require 'lpeg'

local R, P, S, C, V, Cp, Cs, Ct, Cmt, Cc, Cf, Cg = lpeg.R, lpeg.P, lpeg.S, lpeg.C, lpeg.V, lpeg.Cp, lpeg.Cs, lpeg.Ct, lpeg.Cmt, lpeg.Cc, lpeg.Cf, lpeg.Cg
local lpegmatch = lpeg.match
local find, gmatch, match, lower, upper, gsub = string.find, string.gmatch, string.match, string.lower, string.upper, string.gsub
local concat = table.concat
local global = _G
local type, next, setmetatable, rawset = type, next, setmetatable, rawset

if lexer then
    -- in recent c++ code the lexername and loading is hard coded
elseif _LEXERHOME then
    dofile(_LEXERHOME .. '/lexer.lua') -- pre 3.03 situation
else
    dofile('lexer.lua') -- whatever
end

lexer.context    = lexer.context or { }
local context    = lexer.context

context.patterns = context.patterns or { }
local patterns   = context.patterns

lexer._CONTEXTEXTENSIONS = true

local locations = {
 -- lexer.context.path,
   "data", -- optional data directory
   "..",   -- regular scite directory
}

local function collect(name)
--  local definitions = loadfile(name .. ".luc") or loadfile(name .. ".lua")
    local okay, definitions = pcall(function () return require(name) end)
    if okay then
        if type(definitions) == "function" then
            definitions = definitions()
        end
        if type(definitions) == "table" then
            return definitions
        end
    end
end

function context.loaddefinitions(name)
    for i=1,#locations do
        local data = collect(locations[i] .. "/" .. name)
        if data then
            return data
        end
    end
end

-- maybe more efficient:

function context.word_match(words,word_chars,case_insensitive)
    local chars = '%w_' -- maybe just "" when word_chars
    if word_chars then
        chars = '^([' .. chars .. gsub(word_chars,'([%^%]%-])', '%%%1') ..']+)'
    else
        chars = '^([' .. chars ..']+)'
    end
    if case_insensitive then
        local word_list = { }
        for i=1,#words do
            word_list[lower(words[i])] = true
        end
        return P(function(input, index)
            local s, e, word = find(input,chars,index)
            return word and word_list[lower(word)] and e + 1 or nil
        end)
    else
        local word_list = { }
        for i=1,#words do
            word_list[words[i]] = true
        end
        return P(function(input, index)
            local s, e, word = find(input,chars,index)
            return word and word_list[word] and e + 1 or nil
        end)
    end
end

local idtoken = R("az","AZ","\127\255","__")
local digit   = R("09")
local sign    = S("+-")
local period  = P(".")
local space   = S(" \n\r\t\f\v")

patterns.idtoken  = idtoken

patterns.digit    = digit
patterns.sign     = sign
patterns.period   = period

patterns.cardinal = digit^1
patterns.integer  = sign^-1 * digit^1

patterns.real     =
    sign^-1 * (                    -- at most one
        digit^1 * period * digit^0 -- 10.0 10.
      + digit^0 * period * digit^1 -- 0.10 .10
      + digit^1                    -- 10
   )

patterns.restofline = (1-S("\n\r"))^1
patterns.space      = space
patterns.spacing    = space^1
patterns.nospacing  = (1-space)^1
patterns.anything   = P(1)

function context.exact_match(words,word_chars,case_insensitive)
    local characters = concat(words)
    local pattern -- the concat catches _ etc
    if word_chars == true or word_chars == false or word_chars == nil then
        word_chars = ""
    end
    if type(word_chars) == "string" then
        pattern = S(characters) + idtoken
        if case_insensitive then
            pattern = pattern + S(upper(characters)) + S(lower(characters))
        end
        if word_chars ~= "" then
            pattern = pattern + S(word_chars)
        end
    elseif word_chars then
        pattern = word_chars
    end
    if case_insensitive then
        local list = { }
        for i=1,#words do
            list[lower(words[i])] = true
        end
        return Cmt(pattern^1, function(_,i,s)
            return list[lower(s)] -- and i or nil
        end)
    else
        local list = { }
        for i=1,#words do
            list[words[i]] = true
        end
        return Cmt(pattern^1, function(_,i,s)
            return list[s] -- and i or nil
        end)
    end
end

-- spell checking (we can only load lua files)

-- return {
--     words = {
--         ["someword"]    = "someword",
--         ["anotherword"] = "Anotherword",
--     },
-- }

local lists = { }

local splitter = (Cf(Ct("") * (Cg(C((1-S(" \t\n\r"))^1 * Cc(true))) + P(1))^1,rawset) )^0
local splitter = (Cf(Ct("") * (Cg(C(R("az","AZ","\127\255")^1) * Cc(true)) + P(1))^1,rawset) )^0

local function splitwords(words)
    return lpegmatch(splitter,words)
end

function context.setwordlist(tag,limit) -- returns hash (lowercase keys and original values)
    if not tag or tag == "" then
        return false
    elseif lists[tag] ~= nil then
        return lists[tag]
    else
        local list = context.loaddefinitions("spell-" .. tag)
        if not list or type(list) ~= "table" then
            lists[tag] = false
            return false
        elseif type(list.words) == "string" then
            list = splitwords(list.words) or false
            lists[tag] = list
            return list
        else
            list = list.words or false
            lists[tag] = list
            return list
        end
    end
end

patterns.wordtoken   = R("az","AZ","\127\255")
patterns.wordpattern = patterns.wordtoken^3 -- todo: if limit and #s < limit then

function context.checkedword(validwords,s,i) -- ,limit
    if not validwords then
        return true, { "text", i }
--         return true, { "default", i }
    else
        -- keys are lower
        local word = validwords[s]
        if word == s then
            return true, { "okay", i } -- exact match
        elseif word then
            return true, { "warning", i } -- case issue
        else
            local word = validwords[lower(s)]
            if word == s then
                return true, { "okay", i } -- exact match
            elseif word then
                return true, { "warning", i } -- case issue
            elseif upper(s) == s then
                return true, { "warning", i } -- probably a logo or acronym
            else
                return true, { "error", i }
            end
        end
    end
end

function context.styleofword(validwords,s) -- ,limit
    if not validwords then
        return "text"
    else
        -- keys are lower
        local word = validwords[s]
        if word == s then
            return "okay" -- exact match
        elseif word then
            return "warning" -- case issue
        else
            local word = validwords[lower(s)]
            if word == s then
                return "okay" -- exact match
            elseif word then
                return "warning" -- case issue
            elseif upper(s) == s then
                return "warning" -- probably a logo or acronym
            else
                return "error"
            end
        end
    end
end

-- overloaded functions

local FOLD_BASE         = SC_FOLDLEVELBASE
local FOLD_HEADER       = SC_FOLDLEVELHEADERFLAG
local FOLD_BLANK        = SC_FOLDLEVELWHITEFLAG

local get_style_at      = GetStyleAt
local get_property      = GetProperty
local get_indent_amount = GetIndentAmount

local h_table, b_table, n_table = { }, { }, { }

setmetatable(h_table, { __index = function(t,level) local v = { level, FOLD_HEADER } t[level] = v return v end })
setmetatable(b_table, { __index = function(t,level) local v = { level, FOLD_BLANK  } t[level] = v return v end })
setmetatable(n_table, { __index = function(t,level) local v = { level              } t[level] = v return v end })

-- local newline    = P("\r\n") + S("\r\n")
-- local splitlines = Ct( ( Ct ( (Cp() * Cs((1-newline)^1) * newline^-1) + (Cp() * Cc("") * newline) ) )^0)
--
-- local lines = lpegmatch(splitlines,text) -- iterating over lines is faster
-- for i=1, #lines do
--     local li = lines[i]
--     local line = li[2]
--     if line ~= "" then
--         local pos = li[1]
--         for i=1,nofpatterns do
--             for s, m in gmatch(line,patterns[i]) do
--                 if hash[m] then
--                     local symbols = fold_symbols[get_style_at(start_pos + pos + s - 1)]
--                     if symbols then
--                         local l = symbols[m]
--                         if l then
--                             local t = type(l)
--                             if t == 'number' then
--                                 current_level = current_level + l
--                             elseif t == 'function' then
--                                 current_level = current_level + l(text, pos, line, s, match)
--                             end
--                             if current_level < FOLD_BASE then -- integrate in previous
--                                 current_level = FOLD_BASE
--                             end
--                         end
--                     end
--                 end
--             end
--         end
--         if current_level > prev_level then
--             folds[line_num] = h_table[prev_level] -- { prev_level, FOLD_HEADER }
--         else
--             folds[line_num] = n_table[prev_level] -- { prev_level }
--         end
--         prev_level = current_level
--     else
--         folds[line_num] = b_table[prev_level] -- { prev_level, FOLD_BLANK }
--     end
--     line_num = line_num + 1
-- end

local newline = P("\r\n") + S("\r\n")
local p_yes   = Cp() * Cs((1-newline)^1) * newline^-1
local p_nop   = newline

local function fold_by_parsing(text,start_pos,start_line,start_level,lexer)
    local foldsymbols = lexer._foldsymbols
    if not foldsymbols then
        return { }
    end
    local patterns = foldsymbols._patterns
    if not patterns then
        return { }
    end
    local nofpatterns = #patterns
    if nofpatterns == 0 then
        return { }
    end
    local folds = { }
    local line_num = start_line
    local prev_level = start_level
    local current_level = prev_level
    local validmatches = foldsymbols._validmatches
    if not validmatches then
        validmatches = { }
        for symbol, matches in next, foldsymbols do -- whatever = { start = 1, stop = -1 }
            if not find(symbol,"^_") then -- brrr
                for s, _ in next, matches do
                    validmatches[s] = true
                end
            end
        end
        foldsymbols._validmatches = validmatches
    end
    local function action_y(pos,line) -- we can consider moving the local functions outside (drawback: folds is kept)
        for i=1,nofpatterns do
            for s, m in gmatch(line,patterns[i]) do
                if validmatches[m] then
                    local symbols = foldsymbols[get_style_at(start_pos + pos + s - 1)]
                    if symbols then
                        local action = symbols[m]
                        if action then
                            if type(action) == 'number' then -- we could store this in validmatches if there was only one symbol category
                                current_level = current_level + action
                            else
                                current_level = current_level + action(text,pos,line,s,m)
                            end
                            if current_level < FOLD_BASE then
                                current_level = FOLD_BASE
                            end
                        end
                    end
                end
            end
        end
        if current_level > prev_level then
            folds[line_num] = h_table[prev_level] -- { prev_level, FOLD_HEADER }
        else
            folds[line_num] = n_table[prev_level] -- { prev_level }
        end
        prev_level = current_level
        line_num = line_num + 1
    end
    local function action_n()
        folds[line_num] = b_table[prev_level] -- { prev_level, FOLD_BLANK }
        line_num = line_num + 1
    end
    if lexer._reset_parser then
        lexer._reset_parser()
    end
    local lpegpattern = (p_yes/action_y + p_nop/action_n)^0 -- not too efficient but indirect function calls are neither but
    lpegmatch(lpegpattern,text)                             -- keys are not pressed that fast ... large files are slow anyway
    return folds
end

local function fold_by_indentation(text,start_pos,start_line,start_level)
    local folds = { }
    local current_line = start_line
    local prev_level = start_level
    for _, line in gmatch(text,'([\t ]*)(.-)\r?\n') do
        if line ~= "" then
            local current_level = FOLD_BASE + get_indent_amount(current_line)
            if current_level > prev_level then -- next level
                local i = current_line - 1
                while true do
                    local f = folds[i]
                    if f and f[2] == FOLD_BLANK then
                        i = i - 1
                    else
                        break
                    end
                end
                local f = folds[i]
                if f then
                    f[2] = FOLD_HEADER
                end -- low indent
                folds[current_line] = n_table[current_level] -- { current_level } -- high indent
            elseif current_level < prev_level then -- prev level
                local f = folds[current_line - 1]
                if f then
                    f[1] = prev_level -- high indent
                end
                folds[current_line] = n_table[current_level] -- { current_level } -- low indent
            else -- same level
                folds[current_line] = n_table[prev_level] -- { prev_level }
            end
            prev_level = current_level
        else
            folds[current_line] = b_table[prev_level] -- { prev_level, FOLD_BLANK }
        end
        current_line = current_line + 1
    end
    return folds
end

local function fold_by_line(text,start_pos,start_line,start_level)
    local folds = { }
    for _ in gmatch(text,".-\r?\n") do
        folds[start_line] = n_table[start_level] -- { start_level }
        start_line = start_line + 1
    end
    return folds
end

local threshold_by_lexer       =  512 * 1024 -- we don't know the filesize yet
local threshold_by_parsing     =  512 * 1024 -- we don't know the filesize yet
local threshold_by_indentation =  512 * 1024 -- we don't know the filesize yet
local threshold_by_line        =  512 * 1024 -- we don't know the filesize yet

function context.fold(text,start_pos,start_line,start_level) -- hm, we had size thresholds .. where did they go
    if text == '' then
        return { }
    end
    local lexer = global._LEXER
    local fold_by_lexer = lexer._fold
    local fold_by_symbols = lexer._foldsymbols
    local filesize = 0 -- we don't know that
    if fold_by_lexer then
        if filesize <= threshold_by_lexer then
            return fold_by_lexer(text,start_pos,start_line,start_level,lexer)
        end
    elseif fold_by_symbols and get_property('fold.by.parsing',1) > 0 then
        if filesize <= threshold_by_parsing then
            return fold_by_parsing(text,start_pos,start_line,start_level,lexer)
        end
    elseif get_property('fold.by.indentation',1) > 0 then
        if filesize <= threshold_by_indentation then
            return fold_by_indentation(text,start_pos,start_line,start_level,lexer)
        end
    elseif get_property('fold.by.line',1) > 0 then
        if filesize <= threshold_by_line then
            return fold_by_line(text,start_pos,start_line,start_level,lexer)
        end
    end
    return { }
end

-- The following code is mostly unchanged:

local function add_rule(lexer, id, rule)
    if not lexer._RULES then
        lexer._RULES = {}
        lexer._RULEORDER = {}
    end
    lexer._RULES[id] = rule
    lexer._RULEORDER[#lexer._RULEORDER + 1] = id
end

local function add_style(lexer, token_name, style)
    local len = lexer._STYLES.len
    if len == 32 then
        len = len + 8
    end
    if len >= 128 then
        print('Too many styles defined (128 MAX)')
    end
    lexer._TOKENS[token_name] = len
    lexer._STYLES[len] = style
    lexer._STYLES.len = len + 1
end

local function join_tokens(lexer)
    local patterns, order = lexer._RULES, lexer._RULEORDER
    local token_rule = patterns[order[1]]
    for i=2,#order do
        token_rule = token_rule + patterns[order[i]]
    end
    lexer._TOKENRULE = token_rule
    return lexer._TOKENRULE
end

local function add_lexer(grammar, lexer, token_rule)
    local token_rule = join_tokens(lexer)
    local lexer_name = lexer._NAME
    local children = lexer._CHILDREN
    for i=1,#children do
        local child = children[i]
        if child._CHILDREN then
            add_lexer(grammar, child)
        end
        local child_name = child._NAME
        local rules = child._EMBEDDEDRULES[lexer_name]
        local rules_token_rule = grammar['__'..child_name] or rules.token_rule
        grammar[child_name] = (-rules.end_rule * rules_token_rule)^0 * rules.end_rule^-1 * V(lexer_name)
        local embedded_child = '_' .. child_name
        grammar[embedded_child] = rules.start_rule * (-rules.end_rule * rules_token_rule)^0 * rules.end_rule^-1
        token_rule = V(embedded_child) + token_rule
    end
    grammar['__' .. lexer_name] = token_rule
    grammar[lexer_name] = token_rule^0
end

local function build_grammar(lexer, initial_rule)
    local children = lexer._CHILDREN
    if children then
        local lexer_name = lexer._NAME
        if not initial_rule then
            initial_rule = lexer_name
        end
        local grammar = { initial_rule }
        add_lexer(grammar, lexer)
        lexer._INITIALRULE = initial_rule
        lexer._GRAMMAR = Ct(P(grammar))
    else
        lexer._GRAMMAR = Ct(join_tokens(lexer)^0)
    end
end

-- so far. We need these local functions in the next one.

function context.lex(text,init_style)
    local lexer = global._LEXER
    local grammar = lexer._GRAMMAR
    if not grammar then
        return { }
    elseif lexer._LEXBYLINE then -- we could keep token
        local tokens = { }
        local offset = 0
        local noftokens = 0
        if true then
            for line in gmatch(text,'[^\r\n]*\r?\n?') do -- could be an lpeg
                local line_tokens = lpegmatch(grammar,line)
                if line_tokens then
                    for i=1,#line_tokens do
                        local token = line_tokens[i]
                        token[2] = token[2] + offset
                        noftokens = noftokens + 1
                        tokens[noftokens] = token
                    end
                end
                offset = offset + #line
                if noftokens > 0 and tokens[noftokens][2] ~= offset then
                    noftokens = noftokens + 1
                    tokens[noftokens] = { 'default', offset + 1 }
                end
            end
        else -- alternative
            local lasttoken, lastoffset
            for line in gmatch(text,'[^\r\n]*\r?\n?') do -- could be an lpeg
                local line_tokens = lpegmatch(grammar,line)
                if line_tokens then
                    for i=1,#line_tokens do
                        lasttoken = line_tokens[i]
                        lastoffset = lasttoken[2] + offset
                        lasttoken[2] = lastoffset
                        noftokens = noftokens + 1
                        tokens[noftokens] = lasttoken
                    end
                end
                offset = offset + #line
                if lastoffset ~= offset then
                    lastoffset = offset + 1
                    lasttoken = { 'default', lastoffset }
                    noftokens = noftokens + 1
                    tokens[noftokens] = lasttoken
                end
            end
        end
        return tokens
    elseif lexer._CHILDREN then
        -- as we cannot print, tracing is not possible ... this might change as we can as well
        -- generate them all in one go (sharing as much as possible)
        local _hash = lexer._HASH
        if not hash then
            hash = { }
            lexer._HASH = hash
        end
        grammar = hash[init_style]
        if grammar then
            lexer._GRAMMAR = grammar
        else
            for style, style_num in next, lexer._TOKENS do
                if style_num == init_style then
                    -- the name of the lexers is filtered from the whitespace
                    -- specification
                    local lexer_name = match(style,'^(.+)_whitespace') or lexer._NAME
                    if lexer._INITIALRULE ~= lexer_name then
                        grammar = hash[lexer_name]
                        if not grammar then
                            build_grammar(lexer,lexer_name)
                            grammar = lexer._GRAMMAR
                            hash[lexer_name] = grammar
                        end
                    end
                    break
                end
            end
            grammar = grammar or lexer._GRAMMAR
            hash[init_style] = grammar
        end
        return lpegmatch(grammar,text)
    else
        return lpegmatch(grammar,text)
    end
end

-- todo: keywords: one lookup and multiple matches

function context.token(name, patt)
    return Ct(patt * Cc(name) * Cp())
end

lexer.fold        = context.fold
lexer.lex         = context.lex
lexer.token       = context.token
lexer.exact_match = context.exact_match

-- helper .. alas ... the lexer's lua instance is rather crippled .. not even
-- math is part of it

local floor = math and math.floor
local char  = string.char

if not floor then

    floor = function(n)
        return tonumber(string.format("%d",n))
    end

    math = math or { }

    math.floor = floor

end

local function utfchar(n)
    if n < 0x80 then
        return char(n)
    elseif n < 0x800 then
        return char(
            0xC0 + floor(n/0x40),
            0x80 + (n % 0x40)
        )
    elseif n < 0x10000 then
        return char(
            0xE0 + floor(n/0x1000),
            0x80 + (floor(n/0x40) % 0x40),
            0x80 + (n % 0x40)
        )
    elseif n < 0x40000 then
        return char(
            0xF0 + floor(n/0x40000),
            0x80 + floor(n/0x1000),
            0x80 + (floor(n/0x40) % 0x40),
            0x80 + (n % 0x40)
        )
    else
     -- return char(
     --     0xF1 + floor(n/0x1000000),
     --     0x80 + floor(n/0x40000),
     --     0x80 + floor(n/0x1000),
     --     0x80 + (floor(n/0x40) % 0x40),
     --     0x80 + (n % 0x40)
     -- )
        return "?"
    end
end

context.utfchar = utfchar

-- a helper from l-lpeg:

local gmatch = string.gmatch

local function make(t)
    local p
    for k, v in next, t do
        if not p then
            if next(v) then
                p = P(k) * make(v)
            else
                p = P(k)
            end
        else
            if next(v) then
                p = p + P(k) * make(v)
            else
                p = p + P(k)
            end
        end
    end
    return p
end

function lpeg.utfchartabletopattern(list)
    local tree = { }
    for i=1,#list do
        local t = tree
        for c in gmatch(list[i],".") do
            if not t[c] then
                t[c] = { }
            end
            t = t[c]
        end
    end
    return make(tree)
end

-- patterns.invisibles =
--     P(utfchar(0x00A0)) -- nbsp
--   + P(utfchar(0x2000)) -- enquad
--   + P(utfchar(0x2001)) -- emquad
--   + P(utfchar(0x2002)) -- enspace
--   + P(utfchar(0x2003)) -- emspace
--   + P(utfchar(0x2004)) -- threeperemspace
--   + P(utfchar(0x2005)) -- fourperemspace
--   + P(utfchar(0x2006)) -- sixperemspace
--   + P(utfchar(0x2007)) -- figurespace
--   + P(utfchar(0x2008)) -- punctuationspace
--   + P(utfchar(0x2009)) -- breakablethinspace
--   + P(utfchar(0x200A)) -- hairspace
--   + P(utfchar(0x200B)) -- zerowidthspace
--   + P(utfchar(0x202F)) -- narrownobreakspace
--   + P(utfchar(0x205F)) -- math thinspace

patterns.invisibles = lpeg.utfchartabletopattern {
    utfchar(0x00A0), -- nbsp
    utfchar(0x2000), -- enquad
    utfchar(0x2001), -- emquad
    utfchar(0x2002), -- enspace
    utfchar(0x2003), -- emspace
    utfchar(0x2004), -- threeperemspace
    utfchar(0x2005), -- fourperemspace
    utfchar(0x2006), -- sixperemspace
    utfchar(0x2007), -- figurespace
    utfchar(0x2008), -- punctuationspace
    utfchar(0x2009), -- breakablethinspace
    utfchar(0x200A), -- hairspace
    utfchar(0x200B), -- zerowidthspace
    utfchar(0x202F), -- narrownobreakspace
    utfchar(0x205F), -- math thinspace
}

-- now we can make:

patterns.iwordtoken   = patterns.wordtoken - patterns.invisibles
patterns.iwordpattern = patterns.iwordtoken^3

-- require("themes/scite-context-theme")

-- In order to deal with some bug in additional styles (I have no cue what is
-- wrong, but additional styles get ignored and clash somehow) I just copy the
-- original lexer code ... see original for comments.