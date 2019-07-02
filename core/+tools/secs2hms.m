function sString = secs2hms(fSeconds)
%SECS2HMS - converts a time in seconds to a string giving the time in hours, minutes and second
%   Usage STRING = SECS2HMS(TIME)]);
%   Example 1: >> secs2hms(7261)
%   >> ans = 2 hours, 1 min, 1.0 sec
%   Example 2: >> tic; pause(61); disp(['program took ' tools.secs2hms(toc)]);
%   >> program took 1 min, 1.0 secs

% Initializing the return variable
sString = '';

% Initializing variables for the number of hours and minutes
iHours = 0;
iMins = 0;

% Get the number of hours, if the duration is longer than one
if fSeconds >= 3600
    iHours = floor(fSeconds/3600);
    
    % Setting the hour string to the correct singular and plural
    if iHours > 1
        sHourString = ' hours, ';
    else
        sHourString = ' hour, ';
    end
    
    % Concatenating the number and unit
    sString = [num2str(iHours) sHourString];
end

% Get the number of minutes, if the duration is longer than one
if fSeconds >= 60
    iMins = floor((fSeconds - 3600*iHours)/60);
    
    % Setting the minute string to the correct singular and plural
    if iMins > 1
        sMinuteString = ' mins, ';
    else
        sMinuteString = ' min, ';
    end
    
    % Concatenating the number and unit with the string already containing
    % the hours.
    sString = [sString num2str(iMins) sMinuteString];
end

% The number of seconds is calculated via subtraction
iSeconds = fSeconds - 3600 * iHours - 60 * iMins;

% And finally we can add the seconds string to the end of our return
% variable.
sString = [sString sprintf('%2.1f', iSeconds) ' secs'];

end
