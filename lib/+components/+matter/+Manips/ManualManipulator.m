classdef ManualManipulator < matter.manips.substance.stationary
    % This manipulator allows the user to define the desired flowrates by
    % using the a setFlowRate function. It contains an internal check to
    % see if the flowrates add up to zero and if that is not the case tries
    % to equalize the flow rates.
    
    properties (SetAccess = protected, GetAccess = public)
        % parent system reference
        oParent;
        
        % Property to store the manual flow rates in kg/s for each
        % substance that the user defned using the setFlowRate function
        afManualFlowRates; % [kg/s]
    end
    
    methods
        function this = ManualManipulator(oParent, sName, oPhase)
            this@matter.manips.substance.stationary(sName, oPhase);

            this.oParent = oParent;
            
            this.afManualFlowRates = zeros(1,this.oMT.iSubstances);
        end
        
        function setFlowRate(this, afFlowRates)
            % required input for the set flowrate function is a vector with
            % the length of oMT.iSubstances. The entries in the vector
            % correspond to substance flowrates with the substances beeing
            % specified by oMT.tiN2I, each entry represents a flowrate for
            % the respective substance in kg/s. The flowrates have to add up to 0! 
            
            %% for small errors this calculation will minimize the mass balance errors
            fError = sum(afFlowRates);
            if fError < 1e-6
                fPositiveFlowRate = sum(afFlowRates(afFlowRates > 0));
                fNegativeFlowRate = abs(sum(afFlowRates(afFlowRates < 0)));
                
                if fPositiveFlowRate > fNegativeFlowRate
                    % reduce the positive flows by the difference:
                    fDifference = fPositiveFlowRate - fNegativeFlowRate;
                    arRatios = afFlowRates(afFlowRates > 0)./fPositiveFlowRate;
                    
                    afFlowRates(afFlowRates > 0) = afFlowRates(afFlowRates > 0) - fDifference .* arRatios;
                else
                    % reduce the negative flows by the difference:
                    fDifference = fPositiveFlowRate - fNegativeFlowRate;
                    arRatios = abs(afFlowRates(afFlowRates < 0)./fNegativeFlowRate);
                    
                    afFlowRates(afFlowRates < 0) = afFlowRates(afFlowRates < 0) - fDifference .* arRatios;
                end
            else
            %% For larger errors the manipulator will throw an error
                error('The Manual Manipulator was not provided with a flowrate vector that adds up to zero!')
            end
            
            this.afManualFlowRates = afFlowRates;
            
            % call the update function to set the manual flow rates as
            % manipualtor flow rates
            this.update()
        end
    end
    methods (Access = protected)
        function update(this, ~)
            %% sets the flowrate values
            update@matter.manips.substance(this, this.afManualFlowRates);
        end
    end
end