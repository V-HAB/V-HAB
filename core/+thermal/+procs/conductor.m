classdef (Abstract) conductor < base & event.source
    %CONDUCTOR A thermal connection between two capacity objects
    %   This base class can be used to model any thermal conduction
    %   interface between two capacities possible. Child classes that
    %   provide radiative, convective, conductive heat transport exist as
    %   well
    % 
    % ANALOGOUS TO: matter.proc
    
    properties (SetAccess = protected)
        
        % Object properties
        
        sName; % The name of the transfer object. Usually a combination of its associated capacity objects' names.
        
        % Internal properties
        
        oLeft;  % The "left" side of the connection.
        oRight; % The "right" side of the connection.
        
        % The system in which the conductor is located
        oContainer;
        
        % The thermal branch in which this conductor is placed
        oThermalBranch;
        
        % Reference to the matter table object
        oMT;
        % Reference to the timer object
        oTimer;
        
        % Check if the conductor is sealed already
        bSealed = false;
        
        % The thermal solver will need to determine which type of
        % conductor a specific object is. Since isa() is very slow, we
        % create these three boolean variables to improve the speed of the
        % check.
        bRadiative  = false;
        bConvective = false;
        bConductive = false;
    end
    
    % Abstract properties are properties which are not defined yet on this
    % supraclass but are mandatory properties for all subclasses. So any
    % class that inherits from this class must implement the following
    % properties
    properties (Abstract, SetAccess = protected)
        fResistance; % Thermal resistance of connection (unit depends on subclass).
    end
    
    methods
        
        function this = conductor(oContainer, sName)
            % Create a conductive conductor instance and store the name, 
            % associated capacities as well as the (intial) conductivity
            % value.
            
            this.sName = sName;
            this.oContainer = oContainer;
            
            % Add the conductor to the thermal container
            this.oContainer.addProcConductor(this);
            
            this.oMT    = this.oContainer.oMT;
            this.oTimer = this.oContainer.oTimer;
            
        end
        
        
        function seal(this, oThermalBranch)
            % Seal the conductor, prevent further changes and check it for
            % consistency
            if this.bSealed
                this.throw('seal', 'Already sealed!');
            end
            
            % Making sure that the object is configured properly in terms
            % of it's type.
            if sum([this.bRadiative this.bConductive this.bConvective]) > 1
                this.throw('seal', 'You have configured the conductor ''%s'' to be of multiple types. Can only be one (radiative, conductive or convective).', this.sName);
            end
            
            this.oThermalBranch = oThermalBranch;
            
            this.bSealed = true;
        end
    end
end