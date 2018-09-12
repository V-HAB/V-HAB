classdef substance < matter.manip
    % Manipulator for substances. Allows the model to change one substance
    % into another substance, to model chemical reactions. For example
    % electrolysis is the chemical reaction 2 * H2O -> 2 * H2 + O2 which
    % requires the model to change the substance H2O into the substances H2
    % and O2
    
    
    properties (Abstract, SetAccess = protected)
        % Changes in partial masses in kg/s
        afPartialFlows;
        
    end
    
    methods
        function this = substance(sName, oPhase)
            this@matter.manip(sName, oPhase);
            
        end
    end
       
    methods (Abstract)
        % Every child class must implement this function with the
        % corresponding calculation to set the according flow rates
        update(this)
    end
end

