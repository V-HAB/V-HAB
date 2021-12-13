classdef DummyBoschProcess < matter.manips.substance.stationary
    %DUMMYBOSCHPROCESS A dummy model of the Bosch Process
    %   This manipulator converts all of the CO2 in the connected phase to
    %   the according amount of pure carbon and oxygen. 
    %
    %   Note that this manipulator inhertis from the base class
    %   "matter.manips.substance.stationary" as it is used in a normal
    %   phase. If instead the manipulator should convert matter in a flow
    %   phase it should inherit from "matter.manips.substance.flow"
    
    properties (GetAccess = public, SetAccess = protected)
        % When you define properties for a class you should generally use
        % these access rights. The GetAccess should be public so that other
        % objects can look at these values, but the SetAccess should be
        % protected because otherwise any other object could change these
        % properties, which quickly becomes confusing.
        
        % Maximum ratio of CO2 which can be converted to O2 and C
        rMaximumConversion = 0.9;
    end
    methods
        function this = DummyBoschProcess(sName, oPhase, rMaximumConversion)
            this@matter.manips.substance.stationary(sName, oPhase);
            % A manip always receives a name and a phase as
            % inputs. These are the minimal required inputs as the base
            % class of the manip requires them.
            %
            % In addition to these base inputs, the input
            % rMaximumConversion is defined for this specific manipulator.
            % We store it in a property if it is defined for the
            % manipulator. If not, the base value defined for the property
            % will be used.
            if nargin > 2
                this.rMaximumConversion = rMaximumConversion;
            end
        end
    end
    
    methods (Access = protected)
        function update(this)
            % The update function of the manipulator is called
            % automatically in the post tick whenever the phase updates.
            % Therefore, you can define how frequently the manip should be
            % updated by setting the corresponding properties to the phase!
            
            % the manip base class has a helper function which can be used
            % to get the current mass flows ENTERING the phase in which the
            % manip is located.
            afMassFlows = this.getTotalFlowRates();
            
            % Abbreviating some of the variables to make code more legible
            afMolMass  = this.oPhase.oMT.afMolarMass;
            tiN2I      = this.oPhase.oMT.tiN2I;
            
            % Getting the total CO2 massflow entering the phase and
            % multiplying it with the percentage that can be converted
            fMassFlowCO2 = this.rMaximumConversion * afMassFlows(tiN2I.CO2);
            
            % Now we calculate the stochiometric conversion of CO2 into C
            % and O2. For this the mass flow of CO2 is divided with the
            % molar mass of CO2 and then multiplied with the molar mass of
            % C or O2. Since the conversion is CO2 -> C + O2 no other
            % multiplicators are required
            fMassC   = (fMassFlowCO2 / afMolMass(tiN2I.CO2)) * afMolMass(tiN2I.C);
            fMassO2  = (fMassFlowCO2 / afMolMass(tiN2I.CO2)) * afMolMass(tiN2I.O2);
            
            % The manipulator base class requires a vector with the mass
            % flows of all substances available in V-HAB. Therefore, we
            % initialize a zero vector for this, as most mass flows of the
            % manip will be zero
            afPartialFlows = zeros(1, this.oPhase.oMT.iSubstances);
            
            % Now we can set the specific mass flow rates for the
            % substances that shall be converted. Note that the sum of
            % afPartialFlows should always be 0. Mass that is consumed must
            % be set as a negative flowrate!
            afPartialFlows(tiN2I.CO2) = -1 * fMassFlowCO2;
            afPartialFlows(tiN2I.C)   = fMassC;
            afPartialFlows(tiN2I.O2)  = fMassO2;
            
            % Now we can call the parent update method and pass on the
            % afPartials variable.
            update@matter.manips.substance(this, afPartialFlows);
        end
    end
end