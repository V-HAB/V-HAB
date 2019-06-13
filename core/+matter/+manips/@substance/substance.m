classdef (Abstract) substance < matter.manip
    % Manipulator for substances. Allows the model to change one substance
    % into another substance, to model chemical reactions. For example
    % electrolysis is the chemical reaction 2 * H2O -> 2 * H2 + O2 which
    % requires the model to change the substance H2O into the substances H2
    % and O2
    
    properties (Abstract, SetAccess = protected)
        % A vector which describes the changes in partial masses for each
        % possible substance in V-HAB. Every entry represents one
        % substance, and an entry for every possible substance must be
        % present. If the partial mass flow rate of a specific substance
        % from this vector must be identified this is possible by using the
        % matter table with a call like this:
        % this.afPartialFlows(this.oMT.tiN2I.H2O)
        % Each entry represents a flowrate in kg/s
        afPartialFlows; % [kg/s]
        
    end
    
    methods
        function this = substance(sName, oPhase)
            this@matter.manip(sName, oPhase);
            
        end
    end
end