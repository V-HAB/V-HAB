classdef branch < solver.thermal.base.branch
% A basic thermal solver which calculates the heat flow through a thermal
% branch based on the temperature difference between the adjacent phases
% and the conductor values
    
    properties (SetAccess = private, GetAccess = public)
        
        % Actual time between flow rate calculations
        fTimeStep = inf;
        
        fSolverHeatFlow = 0;
    end
    
    
    methods
        function this = branch(oBranch)
            this@solver.thermal.base.branch(oBranch, 0, 'basic');
            
            this.update();
        end
        
    end
    
    methods (Access = protected)
        function update(this)
            
            afConductivity = zeros(1,this.oBranch.iConductors);
            
            for iConductor = 1:this.oBranch.iConductors
                this.oBranch.coConductors{iConductor}.update();
                afConductivity(iConductor) = this.oBranch.coConductors{iConductor}.fConductivity;
            end
            
            fDeltaTemperature = this.oBranch.coExmes{1}.oCapacity.fTemperature - this.oBranch.coExmes{2}.oCapacity.fTemperature;
            
            if ~isempty(this.oBranch.oMassBranch)
                % TO DO: create a seperate solver branch only for mass
                % bound energy transfer?
                iFlowProcs = this.oBranch.oMassBranch.iFlowProcs;

                afF2F_HeatFlows = zeros(1,iFlowProcs);
                for iF2F = 1:iFlowProcs
                    % TO DO: implement this so that f2fs are updated in a
                    % downstream manner, depending on mass branch flowrate
                    try
                        this.oBranch.oMassBranch.aoFlowProcs(iF2F).updateThermal();
                    catch
                        % maybe it is a non thermal f2f
                    end
                    afF2F_HeatFlows(iF2F) = this.oBranch.oMassBranch.aoFlowProcs(iF2F).fHeatFlow;
                end
                
                this.fSolverHeatFlow = afConductivity(end) * (fDeltaTemperature) + sum(afF2F_HeatFlows);
            else
                afF2F_HeatFlows = 0;  
            end
            
            keyboard()
             
            update@solver.thermal.base.branch(this, this.afSolverHeatFlow);
            
        end
    end
end
