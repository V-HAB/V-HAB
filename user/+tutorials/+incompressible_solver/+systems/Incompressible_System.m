classdef Incompressible_System < vsys
    %EXAMPLE Example simulation for V-HAB 2.0
    %   This class creates blubb
    
    properties
        oSystemSolver;
        aoPhases;
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
            
            
            %initial relative humidity that is going to be used for every
            %air phase in the ACLS is assumed to be ~40% (nominal value
            %according to BVAD table 4.1)
            fRelHumidity = 0.4;
            fTemperature = 293;
            
            fDensityAir = this.oData.oMT.findProperty('air',...
                   'Density','Pressure',101325,'Temperature',fTemperature,'gas');
               
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
                ((this.oData.oMT.afMolarMass(this.oData.oMT.tiN2I.('H2O')))/...
                (this.oData.oMT.afMolarMass(this.oData.oMT.tiN2I.('air'))));
            %These are MASS percent, so don't confuse them with volume
            %percent (like 21% oxygen in the air THATS VOLUME PERCENT!)
            fO2Percent = 0.23135;
            fCO2Percent = 0.0038;
            
            fTank_Volume = 0.5;
            if bWater == 0
                sPhase = 'gas';
                tPhase = struct(...
                          'O2',  fTank_Volume * fDensityAir * fO2Percent,...
                          'N2',  fTank_Volume * fDensityAir * (1-(0.23135+0.0038+fH2OMassFraction)),...
                          'CO2', fTank_Volume * fDensityAir * fCO2Percent,...
                          'H2O', fTank_Volume * fDensityAir * fH2OMassFraction );
                      
                tPhase2 = struct(...
                          'O2',  fTank_Volume * 2*fDensityAir * fO2Percent,...
                          'N2',  fTank_Volume * 2*fDensityAir * (1-(0.23135+0.0038+fH2OMassFraction)),...
                          'CO2', fTank_Volume * 2*fDensityAir * fCO2Percent,...
                          'H2O', fTank_Volume * 2*fDensityAir * fH2OMassFraction );
                      
                % Creating a store
                this.addStore(matter.store(this, 'Tank_1', 0.5));
                oPhaseTank(1) = matter.phases.(sPhase)(this.toStores.Tank_1, ...
                              'Tank1_Phase', tPhase, fTank_Volume, fTemperature);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.gas(oPhaseTank(1), 'Port_Out1' );
                matter.procs.exmes.gas(oPhaseTank(1), 'Port_In1' );
                matter.procs.exmes.gas(oPhaseTank(1), 'Port_In2' );

                % Creating a second store
                this.addStore(matter.store(this, 'Tank_2', 0.5));
                oPhaseTank(2) = matter.phases.(sPhase)(this.toStores.Tank_2, ...
                              'Tank2_Phase', tPhase, fTank_Volume, fTemperature);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(2), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(2), 'Port_Out1');

                % Creating a third store
                this.addStore(matter.store(this, 'Tank_3', 0.5));
                oPhaseTank(3) = matter.phases.(sPhase)(this.toStores.Tank_3, ...
                              'Tank3_Phase', tPhase, fTank_Volume, fTemperature);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(3), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(3), 'Port_Out1');
                matter.procs.exmes.(sPhase)(oPhaseTank(3), 'Port_Out2');

                % Creating a fourth store
                this.addStore(matter.store(this, 'Tank_4', 0.5));
                oPhaseTank(4) = matter.phases.(sPhase)(this.toStores.Tank_4, ...
                              'Tank4_Phase', tPhase, fTank_Volume, fTemperature);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(4), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(4), 'Port_Out1');

                % Creating a fifth store
                this.addStore(matter.store(this, 'Tank_5', 0.5));
                oPhaseTank(5) = matter.phases.(sPhase)(this.toStores.Tank_5, ...
                              'Tank5_Phase', tPhase, fTank_Volume, fTemperature);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(5), 'Port_Out1');

                % Creating a sixth store
                this.addStore(matter.store(this, 'Tank_6', 0.5));
                oPhaseTank(6) = matter.phases.(sPhase)(this.toStores.Tank_6, ...
                              'Tank6_Phase', tPhase2, fTank_Volume, fTemperature);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(6), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(6), 'Port_Out1');

                % Creating a seventh store
                this.addStore(matter.store(this, 'Tank_7', 0.5));
                oPhaseTank(7) = matter.phases.(sPhase)(this.toStores.Tank_7, ...
                              'Tank7_Phase', tPhase, fTank_Volume, fTemperature);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(7), 'Port_In1');

                % Creating an eigth store
                this.addStore(matter.store(this, 'Tank_8', 0.5));
                oPhaseTank(8) = matter.phases.(sPhase)(this.toStores.Tank_8, ...
                              'Tank8_Phase', tPhase, fTank_Volume, fTemperature);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(8), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(8), 'Port_Out1');
            
            else
                sPhase = 'liquid';
                fPressure = 101325;
                fDensityWater = this.oData.oMT.findProperty('H2O',...
                   'Density','Pressure',fPressure,'Temperature',fTemperature,'liquid');
                tPhase = struct('H2O', fTank_Volume * fDensityWater);
                
                fDensityWater2 = this.oData.oMT.findProperty('H2O',...
                   'Density','Pressure',2*fPressure,'Temperature',fTemperature,'liquid');
                tPhase2 = struct('H2O', fTank_Volume * fDensityWater2);
                
                % Creating a store
                this.addStore(matter.store(this, 'Tank_1', 0.5));
                oPhaseTank(1) = matter.phases.(sPhase)(this.toStores.Tank_1, ...
                              'Tank1_Phase', tPhase, fTank_Volume, fTemperature, fPressure);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(1), 'Port_Out1' );
                matter.procs.exmes.(sPhase)(oPhaseTank(1), 'Port_In1' );
                matter.procs.exmes.(sPhase)(oPhaseTank(1), 'Port_In2' );

                % Creating a second store
                this.addStore(matter.store(this, 'Tank_2', 0.5));
                oPhaseTank(2) = matter.phases.(sPhase)(this.toStores.Tank_2, ...
                              'Tank2_Phase', tPhase, fTank_Volume, fTemperature, fPressure);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(2), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(2), 'Port_Out1');

                % Creating a third store
                this.addStore(matter.store(this, 'Tank_3', 0.5));
                oPhaseTank(3) = matter.phases.(sPhase)(this.toStores.Tank_3, ...
                              'Tank3_Phase', tPhase, fTank_Volume, fTemperature, fPressure);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(3), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(3), 'Port_Out1');
                matter.procs.exmes.(sPhase)(oPhaseTank(3), 'Port_Out2');

                % Creating a fourth store
                this.addStore(matter.store(this, 'Tank_4', 0.5));
                oPhaseTank(4) = matter.phases.(sPhase)(this.toStores.Tank_4, ...
                              'Tank4_Phase', tPhase, fTank_Volume, fTemperature, fPressure);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(4), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(4), 'Port_Out1');

                % Creating a fifth store
                this.addStore(matter.store(this, 'Tank_5', 0.5));
                oPhaseTank(5) = matter.phases.(sPhase)(this.toStores.Tank_5, ...
                              'Tank5_Phase', tPhase, fTank_Volume, fTemperature, fPressure);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(5), 'Port_Out1');

                % Creating a sixth store
                this.addStore(matter.store(this, 'Tank_6', 0.5));
                oPhaseTank(6) = matter.phases.(sPhase)(this.toStores.Tank_6, ...
                              'Tank6_Phase', tPhase2, fTank_Volume, fTemperature, 2*fPressure);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(6), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(6), 'Port_Out1');

                % Creating a seventh store
                this.addStore(matter.store(this, 'Tank_7', 0.5));
                oPhaseTank(7) = matter.phases.(sPhase)(this.toStores.Tank_7, ...
                              'Tank7_Phase', tPhase, fTank_Volume, fTemperature, fPressure);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(7), 'Port_In1');

                % Creating an eigth store
                this.addStore(matter.store(this, 'Tank_8', 0.5));
                oPhaseTank(8) = matter.phases.(sPhase)(this.toStores.Tank_8, ...
                              'Tank8_Phase', tPhase, fTank_Volume, fTemperature, fPressure);

                % Adding extract/merge processors to the phases
                matter.procs.exmes.(sPhase)(oPhaseTank(8), 'Port_In1');
                matter.procs.exmes.(sPhase)(oPhaseTank(8), 'Port_Out1');
            end
            
            
            
            this.aoPhases = oPhaseTank;
            
            % Adding pipes to connect the components
            this.addProcF2F(components.pipe('Pipe_1', 1.0, 0.01, 0.0002));
            this.addProcF2F(components.pipe('Pipe_2', 1.0, 0.01, 0.0002));
            this.addProcF2F(components.pipe('Pipe_3', 1.0, 0.01, 0.0002));
            this.addProcF2F(components.pipe('Pipe_4', 1.0, 0.01, 0.0002));
            this.addProcF2F(components.pipe('Pipe_5', 1.0, 0.01, 0.0002));
            this.addProcF2F(components.pipe('Pipe_6', 1.0, 0.01, 0.0002));
            this.addProcF2F(components.pipe('Pipe_7', 1.0, 0.01, 0.0002));
            this.addProcF2F(components.pipe('Pipe_8', 1.0, 0.01, 0.0002));
            
            this.addProcF2F(tutorials.incompressible_solver.components.fan('Fan_1', 1e4, 1));
            
            oBranch1 = this.createBranch('Tank_1.Port_Out1', {'Pipe_1', 'Fan_1'}, 'Tank_2.Port_In1');
            
            oBranch2 = this.createBranch('Tank_2.Port_Out1', {'Pipe_2'}, 'Tank_3.Port_In1');
            
            oBranch3 = this.createBranch('Tank_3.Port_Out1', {'Pipe_3'}, 'Tank_4.Port_In1');
            
            oBranch4 = this.createBranch('Tank_4.Port_Out1', {'Pipe_4'}, 'Tank_1.Port_In1');
            
            oBranch5 = this.createBranch('Tank_5.Port_Out1', {'Pipe_5'}, 'Tank_6.Port_In1');
            
            oBranch6 = this.createBranch('Tank_6.Port_Out1', {'Pipe_6'}, 'Tank_7.Port_In1');
            
            oBranch7 = this.createBranch('Tank_3.Port_Out2', {'Pipe_7'}, 'Tank_8.Port_In1');
            
            oBranch8 = this.createBranch('Tank_8.Port_Out1', {'Pipe_8'}, 'Tank_1.Port_In2');
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
            
            solver.matter.incompressible_liquid.branch_incompressible_liquid(oBranch1);
            solver.matter.incompressible_liquid.branch_incompressible_liquid(oBranch2);
            solver.matter.incompressible_liquid.branch_incompressible_liquid(oBranch3);
            solver.matter.incompressible_liquid.branch_incompressible_liquid(oBranch4);
            solver.matter.incompressible_liquid.branch_incompressible_liquid(oBranch5);
            solver.matter.incompressible_liquid.branch_incompressible_liquid(oBranch6);
            solver.matter.incompressible_liquid.branch_incompressible_liquid(oBranch7);
            solver.matter.incompressible_liquid.branch_incompressible_liquid(oBranch8);

%             solver.matter.linear.branch(oBranch1);
%             solver.matter.linear.branch(oBranch2);
%             solver.matter.linear.branch(oBranch3);
%             solver.matter.linear.branch(oBranch4);
%             solver.matter.linear.branch(oBranch5);
%             solver.matter.linear.branch(oBranch6);
%             solver.matter.linear.branch(oBranch7);
%             solver.matter.linear.branch(oBranch8);

%             rMaxChange = 1e-3;
%             solver.matter.iterative.branch(oBranch1, rMaxChange, rMaxChange);
%             solver.matter.iterative.branch(oBranch2, rMaxChange, rMaxChange);
%             solver.matter.iterative.branch(oBranch3, rMaxChange, rMaxChange);
%             solver.matter.iterative.branch(oBranch4, rMaxChange, rMaxChange);
%             solver.matter.iterative.branch(oBranch5, rMaxChange, rMaxChange);
%             solver.matter.iterative.branch(oBranch6, rMaxChange, rMaxChange);
%             solver.matter.iterative.branch(oBranch7, rMaxChange, rMaxChange);
%             solver.matter.iterative.branch(oBranch8, rMaxChange, rMaxChange);
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
        end
        
     end
    
end

