function arrangeWindowsTherMoS(aWindows)
%ARRANGEWINDOWSTHERMOS Arranges figure windows from V-HAB but excludes the ones from TherMoS
%   This function arranges any number of windows between 1 and 15 in a 
%   regular pattern for any screen size.
%   All additional windows will be stacked in the default location.
%   The windows created by V-HAB must have their 'UserData' property set to 'V-HAB' for this
%   to work. Also this approach assumes, that the V-HAB Windows are created AFTER the TherMoS 
%   windows.

% Increase the screen resolution from 72 ppi (new MATLAB default) to 96 ppi
% This works well on most modern, high resolution screens
set(groot, 'ScreenPixelsPerInch', 96);

% Getting the number of windows
if nargin < 1 || isempty(aWindows)
    aWindows = flipud(get(0,'Children'));
end

% Now we get the actual number of windows
iNumberOfWindows = length(aWindows);

% Now we need to see, which windows were created by V-HAB, since these are the only ones we want to
% resize. 
iNumberOfVHABWindows = 0;
for iI = 1:iNumberOfWindows
    sUserData = get(aWindows(iI), 'UserData');
    
    if strcmp(sUserData, 'V-HAB')
        iNumberOfVHABWindows = iNumberOfVHABWindows + 1;
    end
    
end

% if there are 3 windows or less, do nothing.
if iNumberOfVHABWindows < 4
    return;
elseif iNumberOfVHABWindows < 11
    % For up to 8 windows, use two horizontal rows
    iNumberOfRows = 2;
else
    % For more than 8 windows, use three horizontal rows
    iNumberOfRows = 3;
end

% Four rows is just too much. Use less windows. :-)

% Determine the number of columns. If the number of windows is uneven, the bottom right
% area will be left empty.
if mod(iNumberOfVHABWindows, iNumberOfRows)
    iNumberOfColumns = ceil(iNumberOfVHABWindows/iNumberOfRows);
    if iNumberOfColumns > 5, iNumberOfColumns = 5; end;
else
    iNumberOfColumns = iNumberOfVHABWindows / iNumberOfRows;
end


% Handle multiple screens: plot where the Matlab main window is positioned!
% NOTE: assuming  that multiple displays are positioned left/right, not
% above/below of each other, i.e. only comparing the x-positions.
aScreenSizes = get(0, 'MonitorPositions');
afPositionsX = sort(aScreenSizes(:, 1));
afMainWinPos = get(0, 'Pointer');

% Sort X-coordinates of displays ASC, find all display coordinates that are
% smaller than the main window X-coordinate and get the largest of those.
% Use that X-coordinate to find the appropiate row in monitor positions.
iScreen      = find(max(afPositionsX(afMainWinPos(1) > afPositionsX)) == aScreenSizes(:, 1));
aScreenSize  = aScreenSizes(iScreen, :);


if ismac
    aScreenSize(4) = aScreenSize(4) - 23;
end

iWidth  = floor( aScreenSize(3) / iNumberOfColumns );
iHeight = floor( aScreenSize(4) / iNumberOfRows );

iLeft   = aScreenSize(1);
iBottom = (iNumberOfRows - 1) * iHeight + aScreenSize(2);
iWindow = iNumberOfWindows - iNumberOfVHABWindows + 1;

for iJ = 1:iNumberOfRows
    for iK = 1:iNumberOfColumns
        aPosition = [iLeft, iBottom + 1, iWidth, iHeight];
        if iWindow > iNumberOfWindows
            return;
        else
            set(aWindows(iWindow), 'OuterPosition', aPosition);
            iLeft = iLeft + iWidth;
            iWindow = iWindow + 1;
        end
    end
    
    iLeft = aScreenSize(1);
    iBottom = iBottom - iHeight;
end

%drawnow();

end

