function stop = outfun(x,optimValues,state)
%This function is used to stop the data fitting process with criteria set
%by users.

stop = false;
% Check if directional derivative is less than .01.
if optimValues.resnorm < 1e-5
    stop = true;
end 
end