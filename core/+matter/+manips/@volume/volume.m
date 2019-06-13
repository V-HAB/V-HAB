classdef (Abstract) volume < matter.manip
    % Manipulator for volumes. Allows the model to change the volume (and
    % correspondingly the pressure) of a phase. This is only the base class
    % which is used to provide a common parent class for all volume
    % manipulators. More definitions are made within 
    % into another substance, to model chemical reactions. For example
    % electrolysis is the chemical reaction 2 * H2O -> 2 * H2 + O2 which
    % requires the model to change the substance H2O into the substances H2
    % and O2
    
    methods
        function this = volume(sName, oPhase, sRequiredType)
            if nargin < 3, sRequiredType = []; end
            
            this@matter.manip(sName, oPhase, sRequiredType);
            
        end
    end
end