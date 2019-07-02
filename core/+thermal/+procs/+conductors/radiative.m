classdef radiative < thermal.procs.conductor
    %RADIATIVE A radiative conductor transferring heat through thermal radiation
    
    properties (SetAccess = protected)
        % Thermal resistance of connection
        fResistance; % [K^4/W].
    end
    
    methods
        function this = radiative(oContainer, sName, fResistance)
            % create a conduction processor which models heat transfer by
            % radiation (transfare rate scales with T^4).
            % The necessary inputs are:
            % oContainer:   The system in which the conductor is placed
            % sName:        the name of this conductor making it uniquily
            %               identifiable on its system
            % fResistance:  the current value for the resistance in [K/W]
            %               for this conductor. Subclasses can overwrite
            %               the update function to recalculate the
            %               resistance.
            
            % Calling the parent constructor
            this@thermal.procs.conductor(oContainer, sName);
            
            % Setting the conductor type to radiative
            this.bRadiative  = true;
            
            % Set resistance
            this.fResistance = fResistance;
        end
               
        function fResistance = update(this, ~)
            % The basic update is here so that no checks are required in
            % case a simple conductor without changing resistance should be
            % modelled. For conductors which require a changing resistance
            % a child class of this class should be created which
            % overwrites the update function and implements a valid
            % recalculation routine for it. Since the thermal branch is not
            % necessarily associated with a matter reference it is not
            % possible to perform updates of the resistance based on matter
            % properties here
            fResistance = this.fResistance;
        end 
    end
end