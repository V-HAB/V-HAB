
sUser = input('GIT username? ', 's');

[ ~, sResults ] = system([ 'findstr /S /R "[^\.]matter\.procs\.exme\(" user/+' sUser '/*' ]);

disp('+---------------------------------------------------------------------+');
disp('| FOUND PLACES where matter.procs.exme is still used                  |');
disp('| (replace with according matter.procs.exmes.gas/.liquid/...)         |');
disp('+---------------------------------------------------------------------+');
disp(sResults);