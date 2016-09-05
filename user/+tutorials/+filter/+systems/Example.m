classdef Example < vsys

    properties
        
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 10);
            % Adding the subsystem
            
            
        	tInitialization.tfMassAbsorber  =   struct('Zeolite5A',10);
            tInitialization.tfMassFlow      =   struct('N2',1 , 'CO2', 0.01, 'O2', 0.23);
            tInitialization.fTemperature    =   293;
            tInitialization.iCellNumber     =   20;
            % this factor times the mass flow^2 will decide the pressure
            % loss. In this case the pressure loss will be 1 bar at a
            % flowrate of 0.1 kg/s
            tInitialization.fFrictionFactor =   100e5;
            
            tInitialization.fConductance = 1;
            
            % TO DO: Should these be stored in the matter table as well?
            % Values for the mass transfer coefficient can be found in the
            % paper ICES-2014-268. Here the values for Zeolite5A are used
            % assuming that the coefficients for 5A and 5A-RK38 are equal.
            mfMassTransferCoefficient = zeros(1,this.oMT.iSubstances);
            mfMassTransferCoefficient(this.oMT.tiN2I.CO2) = 0.003;
            mfMassTransferCoefficient(this.oMT.tiN2I.H2O) = 0.0007;
            tInitialization.mfMassTransferCoefficient =   mfMassTransferCoefficient;
            
            tGeometry.fArea = (18*13E-3)^2;
            
            tGeometry.fAbsorberVolume =   tInitialization.tfMassAbsorber.Zeolite5A/this.oMT.ttxMatter.Zeolite5A.ttxPhases.tSolid.Density;
%             tGeometry.fFlowVolume     =   (((18*13E-3)^2) *16.68*2.54/100) - tGeometry.fAbsorberVolume;
            tGeometry.fFlowVolume     =     1;
            tGeometry.fD_Hydraulic              = 1e-4;
            tGeometry.fAbsorberSurfaceArea      = 70;
            
            oFilter = components.filter.Filter(this, 'Filter', tInitialization, tGeometry);
            
            oFilter.iInternalSteps          = 250;
            oFilter.fMinimumTimeStep        = 1e-8;
            oFilter.fMaximumTimeStep        = 60;
            oFilter.fSteadyStateTimeStep    = 10;
            oFilter.rMaxChange              = 0.005;
            % deactivated steady state simplification under all
            % circumstances
            oFilter.fMaxSteadyStateFlowRateChange = 0;
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
            this.oTimer.setMinStep(1e-12)
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creating a store, volume 1 m^3
            matter.store(this, 'Cabin', 100);
            
            % Adding a phase to the store 'Tank_1', 2 m^3 air
            cAirHelper = matter.helper.phase.create.air_custom(this.toStores.Cabin, 100, struct('CO2', 0.04), 293, 0.25, 1e5);
            
            oGasPhase = matter.phases.gas(this.toStores.Cabin, 'air', cAirHelper{1}, cAirHelper{2}, cAirHelper{3});
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oGasPhase, 'Port_2');
            
            
                        
            %% Adding some pipes
            components.pipe(this, 'Pipe1', 1, 0.005);
            components.pipe(this, 'Pipe2', 1, 0.005);
            
            % Creating the flowpath (=branch) into a subsystem
            % Input parameter format is always: 
            % 'Interface port name', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'SubsystemInput', {'Pipe1'}, 'Cabin.Port_1');
            
            % Creating the flowpath (=branch) out of a subsystem
            % Input parameter format is always: 
            % 'Interface port name', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'SubsystemOutput', {'Pipe2'}, 'Cabin.Port_2');
            
            
            
            
            %%% NOTE!!! setIfFlows has to be done in createMatterStructure!
            
            % Now we need to connect the subsystem with the top level system (this one). This is
            % done by a method provided by the subsystem.
            this.toChildren.Filter.setIfFlows('SubsystemInput', 'SubsystemOutput');
            
            
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            %this.seal();
            % NOT ANY MORE!
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            
            this.toChildren.Filter.setInletFlow(0.1);
            % SOLVERS ETC!
            
            % specific properties for rMaxChange etc, possibly depending on
            % this.tSolverProperties.XXX
            % OR this.oRoot.tSolverProperties !!!
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
%             if this.oTimer.fTime > 200
%                 this.toChildren.Filter.setHeaterPower(1000);
%             end
        end
        
     end
    
end

