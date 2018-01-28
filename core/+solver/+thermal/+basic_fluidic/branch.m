classdef branch < solver.thermal.base.branch
% A basic thermal solver which calculates the heat flow through a thermal
% branch based on the temperature difference between the adjacent phases
% and the conductor values
    
    properties (SetAccess = private, GetAccess = public)
        
        % Actual time between flow rate calculations
        fTimeStep = inf;
        
        afSolverHeatFlow = [0, 0];
        
        bP2P = false;
    end
    
    
    methods
        function this = branch(oBranch)
            this@solver.thermal.base.branch(oBranch, 'basic');
            
            if ~isa(this.oBranch.coConductors{1}.oMassBranch, 'matter.branch')
                this.bP2P = true;
            end
            
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
            
            oMassBranch = this.oBranch.coConductors{1}.oMassBranch;
            fDeltaTemperature = this.oBranch.coExmes{2}.oCapacity.fTemperature - this.oBranch.coExmes{1}.oCapacity.fTemperature;
            

            % Currently for mass bound heat transfer it is not possible to
            % allow different conducitvities in the thermal branch, as that
            % would result in energy beeing destroyed/generated. TO solve
            % this it would be necessary for the branch to store thermal
            % energy, which would be equivalent to the matter branch
            % storing mass. Therefore, the issue is solved by averaging the
            % conducivity values in the branch
            fConductivity = sum(afConductivity) / this.oBranch.iConductors;
            
            fHeatFlow = fConductivity * (fDeltaTemperature);
            
            try
                iFlowProcs      = oMassBranch.iFlowProcs;
            catch
                % in this case we have a p2p
                iFlowProcs = 0;
            end
            
            if fConductivity == 0
                this.afSolverHeatFlow = [0, 0];
                
                afTemperatures = ones(1,iFlowProcs + 1) * this.oBranch.coExmes{1}.oCapacity.fTemperature;
                
                if this.bP2P
                    oMassBranch.setTemperature(afTemperatures(1));
                else
                    for iFlow = 1: iFlowProcs+1
                        oMassBranch.aoFlows(iFlow).setTemperature(afTemperatures(iFlow));
                    end
                end
                
                this.afSolverHeatFlow = [0, 0];
                this.oBranch.coExmes{1}.setHeatFlow(this.afSolverHeatFlow(1));
                this.oBranch.coExmes{2}.setHeatFlow(this.afSolverHeatFlow(2));
                
                update@solver.thermal.base.branch(this, 0, afTemperatures);
                return
            end
            
            afTemperatures  = zeros(1,iFlowProcs + 1); % there is one more flow than f2f procs
            afF2F_HeatFlows = zeros(1,iFlowProcs);
            if oMassBranch.fFlowRate >= 0
                afTemperatures(1) = this.oBranch.coExmes{1}.oCapacity.fTemperature; %temperature of the first flow
                iDirection = 1;
                iFlowProcShifter = -1;
                iExme = 2;
            else
                afTemperatures(end) = this.oBranch.coExmes{2}.oCapacity.fTemperature; %temperature of the first flow
                iDirection = -1;
                iFlowProcShifter = 0;
                iExme = 1;
            end
            
            % for the flows we solve the temperatures in a downstream order
            % and also thermally update the procs in a downstream order
            %
            % e.g. we have two f2f thus 3 flows and a positive flow
            % direction. Then:
            % afTemperatures(1) = temperature of left capacity
            % afF2F_HeatFlows(2) = heatflow of first f2f, updated after
            % first temperature is known and therefore before the second
            % flow temperature is set
            
            if this.bP2P
                oMassBranch.setTemperature(afTemperatures(1));
            else
                for iFlow = sif(oMassBranch.fFlowRate >= 0, 2:(iFlowProcs + 1), (iFlowProcs):-1:1)
                    try
                        oMassBranch.aoFlowProcs(iFlow - iDirection).updateThermal();
                    catch
                        % thermally not active f2f
                    end
                    % The thermal energy from the f2f before this flow is added
                    % to the overall heat flow
                    afF2F_HeatFlows(iFlow) = oMassBranch.aoFlowProcs(iFlow + iFlowProcShifter).fHeatFlow;

                    afTemperatures(iFlow) = afTemperatures(iFlow - iDirection) + ((fHeatFlow + afF2F_HeatFlows (iFlow)) / fConductivity);

                    oMassBranch.aoFlows(iFlow).setTemperature(afTemperatures(iFlow))

                end
            end
            % for matter bound heat transfer only the side receiving the
            % mass receives the heat flow, the energy change on the other
            % side is handled by changing the total heat capacity
            this.afSolverHeatFlow = [0, 0];
            if iExme == 1
                this.afSolverHeatFlow(iExme) = fHeatFlow + sum(afF2F_HeatFlows);
            else
                % for a positive flow rate (iExme == 2) the heat is
                % added/subtracted from the right phase. The calculation
                % for the fHeatFlow included this assumption, but the F2F
                % heat sources only tell us if it gets colder or warmer
                % with their sign. For this case an increase in temperature
                % is represented by a negative heat flow because the exme
                % also has a negative sign --> we have to subtract the f2f
                % heat flows
                this.afSolverHeatFlow(iExme) = - fHeatFlow - sum(afF2F_HeatFlows);
            end
            
            % If the mass transfer is matter bound the heat flow is only
            % added to the phase receiving the mass but not subtracted from
            % the other side (a phase that empties does not change its
            % temperature). Therefore, two heat flow values are kept up
            % till this point, where the information is set to the exmes.
            % If the transfer is not matter bound the heat flows are
            % identical (also in sign, because the sign for the respective
            % phase is stored in the exme)
            this.oBranch.coExmes{1}.setHeatFlow(this.afSolverHeatFlow(1));
            this.oBranch.coExmes{2}.setHeatFlow(this.afSolverHeatFlow(2));
            
            fHeatFlow = this.afSolverHeatFlow(this.afSolverHeatFlow ~= 0);
             
            update@solver.thermal.base.branch(this, fHeatFlow, afTemperatures);
            
        end
    end
end
