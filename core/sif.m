function xRtn = sif(bCond, xOne, xTwo)
    %SIF Short if-conditon
    %   Allows for an if condition to be written in a single line of code.
    %   This can be used to make code more compact and easier to read. 
    
    if bCond, xRtn = xOne;
    else      xRtn = xTwo;
    end
    
end

