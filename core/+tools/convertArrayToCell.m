function cxCell = convertArrayToCell(axArray)
    %CONVERTARRAYTOCELL Converts an array into a linear cell
    
    % Getting the length of the input array
    iLength = length(axArray);
    
    % Initializing the return variable
    cxCell = cell(iLength,1);
    
    % Looping through the array items in a linear fashion and adding them to
    % the cell.
    for iI = 1:iLength
        cxCell{iI} = axArray(iI);
    end
    
end

