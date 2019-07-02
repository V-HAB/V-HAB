classdef (Abstract) substance < matter.manip
    % Manipulator for substances. Allows the model to change one substance
    % into another substance, to model chemical reactions. For example
    % electrolysis is the chemical reaction 2 * H2O -> 2 * H2 + O2 which
    % requires the model to change the substance H2O into the substances H2
    % and O2
    
    properties (SetAccess = private, GetAccess = public)
        % Access to these properties is private to enforce setting them
        % through the update function of this class and not a subclass
        % function. This is necessary to ensure that sanity checks are
        % performed and the mass error created by the manipulator is
        % calculated and logged. Since manipualtors can fairly easily
        % create/destroy mass this check is necessary
        
        % A vector which describes the changes in partial masses for each
        % possible substance in V-HAB. Every entry represents one
        % substance, and an entry for every possible substance must be
        % present. If the partial mass flow rate of a specific substance
        % from this vector must be identified this is possible by using the
        % matter table with a call like this:
        % this.afPartialFlows(this.oMT.tiN2I.H2O)
        % Each entry represents a flowrate in kg/s
        afPartialFlows; % [kg/s]
        
        % The time at which the update function of this manip was last
        % executed
        fLastExec = 0; % [s]
        
        % Total mass created (for positive values) or destroyed (for
        % negative values) of this manip. Since manipulators are allowed to
        % change one mass into another it is not possible to discren which
        % specific mass is producing the mass error. Only the total value
        % can be calculated and logged
        fTotalError = 0; % [kg]
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % see description of the abstract property on the manip class for a
        % description of this property and its access rights
        hBindPostTickUpdate;
    end
    
    methods
        function this = substance(sName, oPhase)
            %% Constructor
            % constructor for substance manipulators. Note that this class
            % is abstract and therefore cannot be constructed directly.
            % Only implemented child classes can be constructed, which then
            % also call this superclass constructor
            % Inputs:
            % sName:    Name for this manip
            % oPhase:   Phase object in which this manip is located
            this@matter.manip(sName, oPhase);
            
            this.afPartialFlows = zeros(1, this.oPhase.oMT.iSubstances);
            
            this.hBindPostTickUpdate = this.oTimer.registerPostTick(@this.update, 'matter', 'substanceManips');
        end
    end
    
    methods (Access = protected)
        function update(this, afPartialFlows)
            %% Update
            % INTERNAL FUNCTION! Is executed within the post tick and
            % should therefore not be executed directly. Note that this
            % function is used to set the partial flow rates, but only
            % because the non abstract child class must implement an update
            % method which calculates the values and then uses the
            % superclass update methods to set the flowrates!
            % Execution of the update can be registered using the
            % registerUpdate function of matter.manip
            %
            % This update function can be used to set the mass changes of the
            % asscociated phase. Overloaded by the derived children, which can then
            % access this function to set the mass change by using
            % update@matter.manips.substance(this, afPartialFlows);
            %
            % Required Inputs:
            % afPartialFlows:   Vector with the length (1, oMT.iSubstances)
            %                   which described the partial mass change for
            %                   each substance in kg/s
            
            % Checking if any of the flow rates being set are NaNs. It is
            % necessary to do this here so the origin of NaNs can be found
            % easily during debugging. 
            if any(isnan(afPartialFlows)) || any(isinf(afPartialFlows))
                error('Error in manipulator %s. Some of the flow rates are NaN or inf.', this.sName);
            end
            
            %% Calculates the mass error for this manipulator
            % First we calculate how much time has passed since the update
            % was last called
            fElapsedTime = this.oTimer.fTime - this.fLastExec;
            % To save calculation time we only perform the error
            % calculation if time has passed, since otherwise the added
            % error would be zero anyway
            if fElapsedTime > 0
                % then we calculate the total error of the current (not the
                % new) flow rates in kg/s
                fError = sum(this.afPartialFlows);
                % Now we add the created error in kg (kg/s * s) to the total
                % error produced in earlier time steps
                this.fTotalError = this.fTotalError + (fError * fElapsedTime);
                % to perform the next error calculation correctly now set the
                % update time
                this.fLastExec = this.oTimer.fTime;
            end
            
            % sets the flowrate values
            this.afPartialFlows = afPartialFlows;
        end
    end
end