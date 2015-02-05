
disp('Find''s all strings like "%TODO xyz ..." or "%NOTE abc"');

sSearch = upper((input('Search string (default: TODO)? ', 's')));

if isempty(sSearch), sSearch = 'TODO'; end;

disp([ 'Searching for %' sSearch ]);


%[ ~, sResults ] = system([ 'findstr /S /R "[^\.]matter\.procs\.exme\(" user/+' sUser '/*' ]);


[ ~, sResults ] = system([ 'findstr /N /S "%' sSearch '" user/*.m' ]);

disp('+---------------------------------------------------------------------+');
disp('| SEARCH STRING in user/*                                             |');
%disp('| (replace with according matter.procs.exmes.gas/.liquid/...)         |');
disp('+---------------------------------------------------------------------+');
sLine = '';

while ~isempty(sResults)
    [ sLine, sResults ] = strtok(strtrim(sResults), sprintf('\n'));
    
    [ sFile, sContext ] = strtok(sLine, '    ');
    
    sFile = strtrim(sFile);
    sContext = strtrim(sContext);
    
    [ sFile, sLine ] = strtok(sFile(1:(end - 1)), ':');
    
    disp([ '<a href="matlab:opentoline(' sFile ',' sLine(2:end) ')">' sFile ':' sLine(2:end) '</a>    ' sContext ]);
end




return;
[ ~, sResults ] = system([ 'findstr /N /S "%' sSearch '" core/*.m' ]);

disp('+---------------------------------------------------------------------+');
disp('| SEARCH STRING in core/*                                             |');
%disp('| (replace with according matter.procs.exmes.gas/.liquid/...)         |');
disp('+---------------------------------------------------------------------+');
%disp(sResults);
sLine = '';

while ~isempty(sResults)
    [ sLine, sResults ] = strtok(strtrim(sResults), sprintf('\n'));
    
    [ sFile, sContext ] = strtok(sLine, '    ');
    
    sFile = strtrim(sFile);
    sContext = strtrim(sContext);
    
    [ sFile sLine ] = strtok(sFile(1:(end - 1)), ':');
    
    disp([ '<a href="matlab:opentoline(' sFile ',' sLine(2:end) ')">' sFile ':' sLine(2:end) '</a>    ' sContext ]);
end