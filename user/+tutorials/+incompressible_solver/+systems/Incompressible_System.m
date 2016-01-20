classdef Incompressible_System < vsys
    %EXAMPLE Example simulation for V-HAB 2.0
    %   This class creates blubb
    
    properties
        %Object for the System solver since the incompressible liquid
        %solver does not calculate each branch individually but instead
        %calculates all branches at once with regard to dependencies
        %between the branches
        oSystemSolver;
        
        aoPhases;
        bWater;
    end
    
    methods
        function this = Incompressible_System(oParent, sName, bWater)
            % Call parent constructor. Third parameter defined how often
            % the .exec() method of this subsystem is called. This can be
            % used to change the system state, e.g. close valves or switch
            % on/off components.
            % Values can be: 0-inf for interval in [s] (zero means with
            % lowest time step set for the timer). -1 means with every TICK
            % of the timer, which is determined by the smallest time step
            % of any of the systems. Providing a logical false (def) means
            % the .exec method is called when the oParent.exec() is
            % executed (see this .exec() method - always call exec@vsys as
            % well!).
            this@vsys(oParent, sName, 60);
            
            this.bWater = bWater;
        end
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            %initial relative humidity that is going to be used for every
            %air phase in the ACLS is assumed to be ~40% (nominal value
            %according to BVAD table 4.1)
            fRelHumidity = 0.4;
            fTemperature = 293;
            
            %sets the N2 struct for the matter table with the required
            %information about the nitrogen to get the density
            tN2Density = struct();
            tN2Density.sSubstance = 'N2';
            tN2Density.sProperty = 'Density';
            tN2Density.sFirstDepName = 'Temperature';
            tN2Density.fFirstDepValue = fTemperature;
            tN2Density.sPhaseType = 'gas';
            tN2Density.sSecondDepName = 'Pressure';
            tN2Density.fSecondDepValue = 101325;
            
            fDensityN2 = this.oMT.findProperty(tN2Density);
               
            %paramters taken from the NIST chemistry webbook
            fA = 4.6543;
            fB = 1435.264;
            fC = -64.848;
            %Antoine Equation 
            fPVaporH2O = (10^(fA -(fB/(fTemperature+fC))))*10^5; 
            fPartialPressureH2O = fRelHumidity*fPVaporH2O;
            %the mass fraction of H2O in the chamber can be calculate by
            %multiplying the ratio between the partial pressure for H2O and 
            %the chamber pressure with the ratio between the mol mass for
            %water and the mol mass for air
            fH2OMassFraction = (fPartialPressureH2O/101325)*...
                ((this.oMT.afMolarMass(this.oMT.tiN2I.('H2O')))/...
                (this.oMT.afMolarMass(this.oMT.tiN2I.('N2'))));
            %These are MASS percent, so don't confuse them with volume
            %percent (like 21% oxygen in the air THATS VOLUME PERCENT!)
            fO2Percent = 0.23135;
            fCO2Percent = 0.0038;
            
            fTank_Volume = 0.5;
            if this.bWater == 0
                sPhase = 'gas';
                tPhase = struct(...
                          'O2',  fTank_Volume * fDensityN2 * fO2Percent,...
                          'N2',  fTank_Volume * fDensityN2 * (1-(0.23135+0.0038+fH2OMassFraction)),...
                          'CO2', fTank_Volume * fDensityN2 * fCO2Percent,...
                          'H2O', fTank_Volume * fDensityN2 * fH2OMassFraction );
                      
                tPhase2 = struct(...
                          'O2',  fTank_Volume * 2*fDensityN2 * fO2Percent,...
                          'N2',  fTank_Volume * 2*fDensityN2 * (1-(0.23135+0.0038+fH2OMassFraction)),...
                          'CO2', fTank_Volume * 2*fDensityN2 * fCO2Percent,...
                          'H2O', fTank_Volume * 2*fDensityN2 * fH2OMassFraction );
                      
                % Creating a store
                matter.store(this, 'Tank_1', fTank_Volume);
                
                oPhaseTank(1) = matter.phases.(sPhase)(this.toStores.Tank_1, ...
                              'Tank1_Phase', tPhase, fTank_Volume, fTemperature);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.gas(oPhaseTank(1), 'Port_Out1' );
                matter.procs.exmes.gas(oPhaseTank(1), 'Port_In1' );
                matter.procs.exmes.gas(oPhaseTank(1), 'Port_In2' );

                % Creating a second store
                matter.store(this, 'Tank_2', fTank_Volume);
                oPhaseTank(2) = matter.phases.(sPhase)(this.toStores.Tank_2, ...
                              'Tank2_Phase', tPhase, fTank_Volume, fTemperature);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(2), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(2), 'Port_Out1');

                % Creating a third store
                matter.store(this, 'Tank_3', fTank_Volume);
                oPhaseTank(3) = matter.phases.(sPhase)(this.toStores.Tank_3, ...
                              'Tank3_Phase', tPhase, fTank_Volume, fTemperature);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(3), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(3), 'Port_Out1');
                matter.procs.exmes.(sPhase)(oPhaseTank(3), 'Port_Out2');

                % Creating a fourth store
                matter.store(this, 'Tank_4', fTank_Volume);
                oPhaseTank(4) = matter.phases.(sPhase)(this.toStores.Tank_4, ...
                              'Tank4_Phase', tPhase, fTank_Volume, fTemperature);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(4), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(4), 'Port_Out1');

                % Creating a fifth store
                matter.store(this, 'Tank_5', fTank_Volume);
                oPhaseTank(5) = matter.phases.(sPhase)(this.toStores.Tank_5, ...
                              'Tank5_Phase', tPhase, fTank_Volume, fTemperature);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(5), 'Port_Out1');

                % Creating a sixth store
                matter.store(this, 'Tank_6', fTank_Volume);
                oPhaseTank(6) = matter.phases.(sPhase)(this.toStores.Tank_6, ...
                              'Tank6_Phase', tPhase2, fTank_Volume, fTemperature);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(6), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(6), 'Port_Out1');

                % Creating a seventh store
                matter.store(this, 'Tank_7', fTank_Volume);
                oPhaseTank(7) = matter.phases.(sPhase)(this.toStores.Tank_7, ...
                              'Tank7_Phase', tPhase, fTank_Volume, fTemperature);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(7), 'Port_In1');

                % Creating an eigth store
                matter.store(this, 'Tank_8', fTank_Volume);
                oPhaseTank(8) = matter.phases.(sPhase)(this.toStores.Tank_8, ...
                              'Tank8_Phase', tPhase, fTank_Volume, fTemperature);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(8), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(8), 'Port_Out1');
            
            else
                sPhase = 'liquid';
                fPressure = 101325;
                
                %sets the H2O struct for the matter table with the required
                %information about the water to get the density
                tH2ODensity = struct();
                tH2ODensity.sSubstance = 'H2O';
                tH2ODensity.sProperty = 'Density';
                tH2ODensity.sFirstDepName = 'Temperature';
                tH2ODensity.fFirstDepValue = fTemperature;
                tH2ODensity.sPhaseType = sPhase;
                tH2ODensity.sSecondDepName = 'Pressure';
                tH2ODensity.fSecondDepValue = fPressure;
            
                %density at twice the pressure
                tH2ODensity2 = struct();
                tH2ODensity2.sSubstance = 'H2O';
                tH2ODensity2.sProperty = 'Density';
                tH2ODensity2.sFirstDepName = 'Temperature';
                tH2ODensity2.fFirstDepValue = fTemperature;
                tH2ODensity2.sPhaseType = sPhase;
                tH2ODensity2.sSecondDepName = 'Pressure';
                tH2ODensity2.fSecondDepValue = 2*fPressure;
                
                fDensityWater = this.oMT.findProperty(tH2ODensity);
                tPhase = struct('H2O', fTank_Volume * fDensityWater);
                
                fDensityWater2 = this.oData.oMT.findProperty(tH2ODensity2);
                tPhase2 = struct('H2O', fTank_Volume * fDensityWater2);
                
                % Creating a store
                matter.store(this, 'Tank_1', fTank_Volume);
                oPhaseTank(1) = matter.phases.(sPhase)(this.toStores.Tank_1, ...
                              'Tank1_Phase', tPhase, fTank_Volume, fTemperature, fPressure);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(1), 'Port_Out1' );
                matter.procs.exmes.(sPhase)(oPhaseTank(1), 'Port_In1' );
                matter.procs.exmes.(sPhase)(oPhaseTank(1), 'Port_In2' );

                % Creating a second store
                matter.store(this, 'Tank_2', fTank_Volume);
                oPhaseTank(2) = matter.phases.(sPhase)(this.toStores.Tank_2, ...
                              'Tank2_Phase', tPhase, fTank_Volume, fTemperature, fPressure);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(2), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(2), 'Port_Out1');

                % Creating a third store
                matter.store(this, 'Tank_3', fTank_Volume);
                oPhaseTank(3) = matter.phases.(sPhase)(this.toStores.Tank_3, ...
                              'Tank3_Phase', tPhase, fTank_Volume, fTemperature, fPressure);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(3), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(3), 'Port_Out1');
                matter.procs.exmes.(sPhase)(oPhaseTank(3), 'Port_Out2');

                % Creating a fourth store
                matter.store(this, 'Tank_4', fTank_Volume);
                oPhaseTank(4) = matter.phases.(sPhase)(this.toStores.Tank_4, ...
                              'Tank4_Phase', tPhase, fTank_Volume, fTemperature, fPressure);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(4), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(4), 'Port_Out1');

                % Creating a fifth store
                matter.store(this, 'Tank_5', fTank_Volume);
                oPhaseTank(5) = matter.phases.(sPhase)(this.toStores.Tank_5, ...
                              'Tank5_Phase', tPhase, fTank_Volume, fTemperature, fPressure);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(5), 'Port_Out1');

                % Creating a sixth store
                matter.store(this, 'Tank_6', fTank_Volume);
                oPhaseTank(6) = matter.phases.(sPhase)(this.toStores.Tank_6, ...
                              'Tank6_Phase', tPhase2, fTank_Volume, fTemperature, 2*fPressure);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(6), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(6), 'Port_Out1');

                % Creating a seventh store
                matter.store(this, 'Tank_7', fTank_Volume);
                oPhaseTank(7) = matter.phases.(sPhase)(this.toStores.Tank_7, ...
                              'Tank7_Phase', tPhase, fTank_Volume, fTemperature, fPressure);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(7), 'Port_In1');

                % Creating an eigth store
                matter.store(this, 'Tank_8', fTank_Volume);
                oPhaseTank(8) = matter.phases.(sPhase)(this.toStores.Tank_8, ...
                              'Tank8_Phase', tPhase, fTank_Volume, fTemperature, fPressure);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(8), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(8), 'Port_Out1');
            end
            
            
            
            this.aoPhases = oPhaseTank;
            
            % Adding pipes to connect the components
            tutorials.incompressible_solver.components.pipe(this, 'Pipe_1', 1, 0.01, 0.0002);
            tutorials.incompressible_solver.components.pipe(this, 'Pipe_2', 1, 0.01, 0.0002);
            tutorials.incompressible_solver.components.pipe(this, 'Pipe_3', 1, 0.01, 0.0002);
            tutorials.incompressible_solver.components.pipe(this, 'Pipe_4', 1, 0.01, 0.0002);
            tutorials.incompressible_solver.components.pipe(this, 'Pipe_5', 1, 0.01, 0.0002);
            tutorials.incompressible_solver.components.pipe(this, 'Pipe_6', 1, 0.01, 0.0002);
            tutorials.incompressible_solver.components.pipe(this, 'Pipe_7', 1, 0.01, 0.0002);
            tutorials.incompressible_solver.components.pipe(this, 'Pipe_8', 1, 0.01, 0.0002);
            
            tutorials.incompressible_solver.components.fan(this, 'Fan_1', 1e4, 1);
            
            matter.branch(this, 'Tank_1.Port_Out1', {'Pipe_1', 'Fan_1'}, 'Tank_2.Port_In1');
            matter.branch(this, 'Tank_2.Port_Out1', {'Pipe_2'}, 'Tank_3.Port_In1');
            matter.branch(this, 'Tank_3.Port_Out1', {'Pipe_3'}, 'Tank_4.Port_In1');
            matter.branch(this, 'Tank_4.Port_Out1', {'Pipe_4'}, 'Tank_1.Port_In1');
            matter.branch(this, 'Tank_5.Port_Out1', {'Pipe_5'}, 'Tank_6.Port_In1');
            matter.branch(this, 'Tank_6.Port_Out1', {'Pipe_6'}, 'Tank_7.Port_In1');
            matter.branch(this, 'Tank_3.Port_Out2', {'Pipe_7'}, 'Tank_8.Port_In1');
            matter.branch(this, 'Tank_8.Port_Out1', {'Pipe_8'}, 'Tank_1.Port_In2');
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            for iI = 1:length(this.aoBranches)
                solver.matter.incompressible_liquid.branch_incompressible_liquid(this.aoBranches(iI));
            end

            iIncompBranches = 8;
            %This matrix defines which branches form an interdependant
            %loop. For each loop the matrix contains one columns that has
            %the branch number within this loop as row entries. This is
            %required for the steady state calculation to set viable steady
            %state flowrates that allow high time steps.
            mLoopBranches = [1;2;3;4;7;8];
            %System Solver Inputs:
            %(oSystem, fMinTimeStep, fMaxTimeStep, fMaxProcentualFlowSpeedChange, iPartialSteps, iLastSystemBranch, fSteadyStateTimeStep, fSteadyStateAcceleration, mLoopBranches)  
            this.oSystemSolver = solver.matter.incompressible_liquid.system_incompressible_liquid(this, 1e-2, 5, 1e-1, 30, iIncompBranches, 10, 10, mLoopBranches);
           
            
%             for iI = 1:length(this.aoBranches)
%                 solver.matter.linear.branch(this.aoBranches(iI));
%             end

%             rMaxChange = 1e-3;
%             for iI = 1:length(this.aoBranches)
%                 solver.matter.iterative.branch(this.aoBranches(iI));
%             end
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
        end
        
     end
    
end

