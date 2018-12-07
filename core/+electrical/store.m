classdef store < base
    %STORE A class describing a store of electrical energy
    %   This abstract class describes a device that stores electrical
    %   energy. An example would be a battery. Stores have only two
    %   terminals, one positive and one negative. The main property is it's
    %   capacity in Joule or Watt seconds. 
    %   A calculateTimeStep() method is provided 
    
    properties (SetAccess = protected, GetAccess = public)
        % Reference to the circuit (electrical.circuit) in which this store
        % is contained
        oCircuit;
        
        % Name of store
        sName;
        
        % How much charge is contained in this source? Initialized as inf,
        % because that is the most common application. If this is a battery
        % or some other type of electrical energy storage device, the
        % value will be changed. Unit is [Ws] or [J]. 
        fCapacity = inf; 
        
        % References to the positive and electrical terminals of this
        % store.
        oPositiveTerminal;
        oNegativeTerminal;
        
        % A boolean describing the state of this store. If it is sealed,
        % nothing about its configuration can be changed. 
        bSealed = false;
        
        % Reference to timer object
        oTimer;
        
        % Point in time at which the update() method was last executed.
        fLastUpdate = 0;
        
        % Time step of this store.
        fTimeStep = 0;
        
        % Fixed time step for updating
        fFixedTimeStep = 1;
        
        % A handle to the set time step method for this specific object as
        % a child of the timer object
        hSetTimeStep;
    end
    
    methods
        function this = store(oCircuit, sName, fCapacity)
            % Create an electrical store object. 
            
            % Setting the reference to the parent circuit object in which
            % this store is contained
            this.oCircuit = oCircuit;
            
            % Setting the name property
            this.sName    = sName;
            
            % Setting the reference to the timer object.
            this.oTimer   = oCircuit.oTimer;
            
            % If the user passed in a value for the capacity, we set that
            % property here, otherwise it remains the default value of Inf.
            if nargin > 2
                this.fCapacity = fCapacity;
            end
            
            % Add this store object to the electrical.circuit
            this.oCircuit.addStore(this);
            
            % Creating two terminals, one for the positive and one for the
            % negative port of this store. 
            this.oPositiveTerminal = electrical.terminal(this);
            this.oNegativeTerminal = electrical.terminal(this);
            
        end
        
        function update(this)
            %UPDATE Re-calculates the time step and sets fLastUpdate
            
            % Re-calculate the time step
            this.calculateTimeStep();
            
            % Saving the last update time
            this.fLastUpdate = this.oTimer.fTime;
        end
        
        function seal(this)
            %SEAL Seals this store so nothing can be changed later on
            
            % Return if we are already sealed
            if this.bSealed, return; end
            
            % Bind the .update method to the timer, with a time step of 0
            % (i.e. smallest step), will be adapted after each .update
            this.hSetTimeStep = this.oTimer.bind(@(~) this.update(), 0);
            
            % Setting the bSealed property to true
            this.bSealed = true;
        end
        
        function oTerminal = getTerminal(this, sTerminalName)
            %GETTERMINAL Method to get a reference to either the positive or negative terminal of a store
            
            if strcmp(sTerminalName, 'positive')
                oTerminal = this.oPositiveTerminal;
            elseif strcmp(sTerminalName, 'negative')
                oTerminal = this.oNegativeTerminal;
            else
                this.throw('getTerminal','There is no terminal ''%s'' on store %s.', sTerminalName, this.sName);
            end
        end
        
    end
    
    
end