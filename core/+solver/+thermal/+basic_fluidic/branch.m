classdef branch < solver.thermal.base.branch
% A basic thermal solver which calculates the heat flow through a thermal
% branch based on the mass transfer occuring in an asscociated
% matter.branch

    properties (SetAccess = private, GetAccess = public)
        % Heat flow of this solver for the left and right exme. A vector is
        % necessary because in mass bound thermal energy transfer only the
        % capacity that receives the mass changes its energy through a
        % solver. For the other phase the temperature remains equal and the
        % thermal energy is reduced by reducing the mass and therefore
        % reducing the total heat capacity
        afSolverHeatFlow = [0, 0];
        
        % P2P from the matter domain are handled like branches in the
        % thermal domain, but there are some possible simplifications for
        % them which speed up the calculation. To perform these quickly the
        % boolean is set once to discren the cases easily.
        bP2P = false;
    end
    
    
    methods
        function this = branch(oBranch)
            % Creat a fluidic thermal solver, which solves the thermal
            % energy transport which occurs when mass is transported from
            % phase to phase
            this@solver.thermal.base.branch(oBranch, 'fluidic');
            
            % Check if the connected matter reference is a branch or a P2P
            % and bind the update of the branch to the corresponding
            % trigger which indicates that the mass flow rate is 
            if ~isa(this.oBranch.coConductors{1}.oMassBranch, 'matter.branch')
                this.bP2P = true;
                
                this.oBranch.coConductors{1}.oMassBranch.bind('setMatterProperties',@(~)this.update());
            else
                this.oBranch.coConductors{1}.oMassBranch.bind('update',@(~)this.update());
            end
            
            % Now we register the solver at the timer, specifying the post
            % tick level in which the solver should be executed. For more
            % information on the execution view the timer documentation.
            % Registering the solver with the timer provides a function as
            % output that can be used to bind the post tick update in a
            % tick resulting in the post tick calculation to be executed
            this.hBindPostTickUpdate = this.oBranch.oTimer.registerPostTick(@this.update, 'thermal' , 'solver');
            
            % And we update the solver to initialize everything
            this.update();
            
        end
    end
    
    methods (Access = protected)
        function update(this)
            % Update the thermal solver
            
            % Update the resistances of the conductors within this branch
            afResistances = zeros(1,this.oBranch.iConductors);
            for iConductor = 1:this.oBranch.iConductors
                afResistances(iConductor) = this.oBranch.coConductors{iConductor}.update();
            end
            
            % Get the temperature difference between the two capacities
            % which this branch connects
            oMassBranch = this.oBranch.coConductors{1}.oMassBranch;
            fDeltaTemperature = this.oBranch.coExmes{1}.oCapacity.fTemperature - this.oBranch.coExmes{2}.oCapacity.fTemperature;
            
            % Currently for mass bound heat transfer it is not possible to
            % allow different conducitvities in the thermal branch, as that
            % would result in energy being destroyed/generated. To solve
            % this it would be necessary for the branch to store thermal
            % energy, which would be equivalent to the matter branch
            % storing mass. Therefore, the issue is solved by averaging the
            % resistance values in the branch
            fResistance = sum(afResistances) / this.oBranch.iConductors;
            
            % The (initial) heat flow is simply calculated by dividing the
            % temperature difference with the resistance (this heat flow
            % neglects the heat flow from F2F processors, which is handled
            % hereafter)
            fHeatFlow = fDeltaTemperature / fResistance;
            
            if this.bP2P
                % In this case we have a p2p
                iFlowProcs = 0;
            else
                iFlowProcs = oMassBranch.iFlowProcs;
            end
             
            % If the resistance is infinite no mass is currently flowing
            % and therefore the heatflows are also 0
            if fResistance == inf
                this.afSolverHeatFlow = [0, 0];
                
                afTemperatures = ones(1,iFlowProcs + 1) * this.oBranch.coExmes{1}.oCapacity.fTemperature;
                
                if this.bP2P
                    oMassBranch.setTemperature(afTemperatures(1));
                else
                    % In this case it is assumed that the F2Fs also do not
                    % produce/consume any heat, as modelling that would
                    % require some more sophisticated models for branches
                    % (where a heater inside a pipe could introduce a
                    % flowrate exiting the branch on both sides, which
                    % could only be modelled if branches were allowed to
                    % store mass)
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
            
            % Now we initialize the values needed to loop through the F2F
            % in the order of the flow passing through them
            afTemperatures  = zeros(1,iFlowProcs + 1); % there is one more flow than f2f procs
            afF2F_HeatFlows = zeros(1,iFlowProcs);
            if oMassBranch.fFlowRate >= 0
                afTemperatures(1) = this.oBranch.coExmes{1}.oCapacity.fTemperature; %temperature of the first flow
                iFirstFlow = 1;
                iDirection = 1;
                iFlowProcShifter = -1;
                iExme = 2;
            else
                afTemperatures(end) = this.oBranch.coExmes{2}.oCapacity.fTemperature; %temperature of the first flow
                iFirstFlow = iFlowProcs + 1;
                iDirection = -1;
                iFlowProcShifter = 0;
                iExme = 1;
            end
            
            % For the flows we solve the temperatures in a downstream order
            % and also thermally update the procs in a downstream order.
            %
            % E.g. we have two f2f thus 3 flows and a positive flow
            % direction. Then:
            % afTemperatures(1) = temperature of left capacity
            % afF2F_HeatFlows(2) = heatflow of first f2f, updated after
            % first temperature is known and therefore before the second
            % flow temperature is set
            if this.bP2P
                % A P2P cannot have F2Fs and therefore we can directly set it
                oMassBranch.setTemperature(afTemperatures(1));
            else
                % For actual matter.branch references the branch can
                % contain multiple F2Fs, we now set the temperatures in the
                % order of the flow passing through them and update them
                % after each other so that each F2F does know the correct
                % flow temperature of the flow before it
                oMassBranch.aoFlows(iFirstFlow).setTemperature(afTemperatures(iFirstFlow));
                
                if oMassBranch.fFlowRate >= 0
                    aiFlows = 2:(iFlowProcs + 1);
                else
                    aiFlows = (iFlowProcs):-1:1;
                end
                
                % Now loop through the remaining flows
                for iFlow = aiFlows
                    
                    if ismethod(oMassBranch.aoFlowProcs(iFlow + iFlowProcShifter),'updateThermal')
                        oMassBranch.aoFlowProcs(iFlow + iFlowProcShifter).updateThermal();
                    end                    
                    
                    % The thermal energy from the f2f is added to the
                    % temperature of the previous flow, thus increasing the
                    % thermal energy
                    afF2F_HeatFlows(iFlow + iFlowProcShifter) = oMassBranch.aoFlowProcs(iFlow + iFlowProcShifter).fHeatFlow;

                    afTemperatures(iFlow) = afTemperatures(iFlow - iDirection) + afF2F_HeatFlows(iFlow + iFlowProcShifter) * fResistance;

                    oMassBranch.aoFlows(iFlow).setTemperature(afTemperatures(iFlow))

                end
            end
            this.afSolverHeatFlow = [0, 0];
            % For matter bound heat transfer only the side receiving the
            % mass receives the heat flow, the energy change on the other
            % side is handled by changing the total heat capacity. The
            % impact of the F2Fs heat flows is simply added to the
            % previously calculated heat flow
            if iExme == 1
                this.afSolverHeatFlow(iExme) = fHeatFlow - sum(afF2F_HeatFlows);
            else
                this.afSolverHeatFlow(iExme) = fHeatFlow + sum(afF2F_HeatFlows);
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
            if isempty(fHeatFlow)
                fHeatFlow = 0;
            end
             
            update@solver.thermal.base.branch(this, fHeatFlow, afTemperatures);
            
        end
    end
end