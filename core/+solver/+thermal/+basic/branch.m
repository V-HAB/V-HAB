classdef branch < solver.thermal.base.branch
% A basic thermal solver which calculates the heat flow through a thermal
% branch based on the temperature difference between the adjacent phases
% and the conductor values. Please note that the conductors in the branch
% are assumed to be in a row between the two capacities, if you want to
% model a parallel heat transfer use multiple branches!
    
    methods
        function this = branch(oBranch)
            % creat a basic thermal solver which can solve heat transfer
            % for convective and conductive or radiative conductors. Note
            % that it is not possibe to combine convective/conductive
            % conductors and radiative conductors in one solver, you have
            % to seperate these heat transfers so that the
            % convective/conductive part and the radiative part are solved
            % seperatly
            this@solver.thermal.base.branch(oBranch, 'basic');
            
            % Now we register the solver at the timer, specifying the post
            % tick level in which the solver should be executed. For more
            % information on the execution view the timer documentation.
            % Registering the solver with the timer provides a function as
            % output that can be used to bind the post tick update in a
            % tick resulting in the post tick calculation to be executed
            this.hBindPostTickUpdate = this.oBranch.oTimer.registerPostTick(@this.update, 'thermal' , 'solver');
            
            % and update the solver to initialize everything
            this.update();
        end
        
    end
    
    methods (Access = protected)
        function update(this)
            % update the thermal solver
            
            % we update the conductors in the branch and identify any
            % radiative conductors (all others are considered conductive,
            % because the heat transfer for them scales with T while
            % radiative heat transfer scales with T^4)
            afResistances = zeros(1,this.oBranch.iConductors);
            bRadiative    = false;
            bConductive   = false;
            
            for iConductor = 1:this.oBranch.iConductors
                if this.oBranch.coConductors{iConductor}.bRadiative
                    bRadiative = true;
                else
                    bConductive = true;
                end
                afResistances(iConductor) = this.oBranch.coConductors{iConductor}.update();
            end
            
            % check if both types are present in the branch at the same
            % time, which is currently not possible
            if bRadiative && bConductive
                this.throw('branch', 'Basic thermal solver cannot calculate conductive/convective and radiative heat transfer at the same time, please use two different branches or use a different solver');
            end
            
            % for conductive/convective heat transfer we use delta T with
            % T1 - T2, for radiative we use T1^4 - T2^4
            if bConductive
                fDeltaTemperature = this.oBranch.coExmes{1}.oCapacity.fTemperature - this.oBranch.coExmes{2}.oCapacity.fTemperature;
            
            else
                fDeltaTemperature = this.oBranch.coExmes{1}.oCapacity.fTemperature^4 - this.oBranch.coExmes{2}.oCapacity.fTemperature^4;
            
            end
            
            % See Wärmeübetragung Polifke equation 3.16, only valid if
            % all resistances are in a row and not parallel, for
            % parallel resistances use multiple branches
            fTotalThermalResistance = sum(afResistances);

            % calculate the heat flow
            fHeatFlow = fDeltaTemperature / fTotalThermalResistance;
            
            % set heat flows
            this.oBranch.coExmes{1}.setHeatFlow(fHeatFlow);
            this.oBranch.coExmes{2}.setHeatFlow(fHeatFlow);
            
            % the temperatures between the conductors are not always
            % required. If it is of interest to model various temperatures
            % multiple thermal branches for each step of the heat transfer
            % can be used e.g. to calculate the wall temperature in a heat
            % exchanger
            afTemperatures = []; 
            update@solver.thermal.base.branch(this, fHeatFlow, afTemperatures);
        end
    end
end
