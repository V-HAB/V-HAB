classdef Two_Tanks < vsys
    %EXAMPLE Example simulation for V-HAB 2.0
    %   This class creates blubb
    
    properties
        oSystemSolver;
        aoPhases;
    end
    
    methods
        function this = Two_Tanks(oParent, sName)
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
            
            % Creating a store
            fTank1_Volume = 0.5;
            this.addStore(matter.store(this, 'Tank_1', 0.5));
            oPhaseTank(1) = matter.phases.gas(this.toStores.Tank_1, ...
                          'Tank1_Phase', ...   % Phase name
                          struct(...
                          'O2',  fTank1_Volume * 2*fDensityAir * fO2Percent,...
                          'N2',  fTank1_Volume * 2*fDensityAir * (1-(0.23135+0.0038+fH2OMassFraction)),...
                          'CO2', fTank1_Volume * 2*fDensityAir * fCO2Percent,...
                          'H2O', fTank1_Volume * 2*fDensityAir * fH2OMassFraction ), ...
                          fTank1_Volume, ...               % Phase volume
                          fTemperature);      % Phase temperature
            
            % Adding extract/merge processors to the phases
            matter.procs.exmes.gas(oPhaseTank(1), 'Port_Out1' );
            
            % Creating a second store
            fTank2_Volume = 0.5;
            this.addStore(matter.store(this, 'Tank_2', 0.5));
            oPhaseTank(2) = matter.phases.gas(this.toStores.Tank_2, ...
                          'Tank2_Phase', ...   % Phase name
                          struct(...
                          'O2',  fTank2_Volume * fDensityAir * fO2Percent,...
                          'N2',  fTank2_Volume * fDensityAir * (1-(0.23135+0.0038+fH2OMassFraction)),...
                          'CO2', fTank2_Volume * fDensityAir * fCO2Percent,...
                          'H2O', fTank2_Volume * fDensityAir * fH2OMassFraction ), ...
                          fTank2_Volume, ...               % Phase volume
                          fTemperature);      % Phase temperature
            
            % Adding extract/merge processors to the phases
            matter.procs.exmes.gas(oPhaseTank(2), 'Port_In1');
            
            this.aoPhases = oPhaseTank;
            
            % Adding pipes to connect the components
            this.addProcF2F(components.pipe('Pipe_1', 1.0, 0.01, 0.0002));
            
            oBranch1 = this.createBranch('Tank_1.Port_Out1', {'Pipe_1'}, 'Tank_2.Port_In1');
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
            
            solver.matter.incompressible_liquid.branch_incompressible_liquid(oBranch1);
            
%             solver.matter.iterative.branch(oBranch1);

        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
        end
        
     end
    
end

