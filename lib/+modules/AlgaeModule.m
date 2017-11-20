classdef AlgaeModule < vsys
    %Create all the tanks needed in order to run the algae reactor
    properties
        oInputBranch;
        oNO3Branch;
        oAerationBranch;
        oFreshwaterInputBranch;
        oO2Branch;
        oHarvestAlgaeBranch;
        oHarvestWastewaterBranch;
        oHarvestSieveBranch;
        oHarvesttoBiomassBranch;
        oHarvesttoWastewaterBranch;
        oOutputAirBranch;
        fAerationPower;
        fDilution ;
        fP_harvest;
        fP_fill;
        fHarvest;
        fHarvestFlowRate;
        oProc_Absorber_Algae;
        oProc_Absorber_Algae2;
        oProc_Manip;
        oProc_Absorber_O2;
        oGeo;
    end
    
    
    
    
    methods
        function this = AlgaeModule(oParent, sName)
            this@vsys(oParent, sName, 15);
            this.fHarvest=0;
            this.fAerationPower=200;
            
            oGeo = geometry.volumes.cuboid(3, 3, 0.026);
            
            % Controls the Power and the initial power can be set
            components.AlgaeModule.PowerControl(this, 'PowerControl');
            
            % Creating the filter store
            this.addStore(matter.store(this.oData.oMT,'FilterAlgaeReactor',10));
            
            
            oFlow = matter.phases.liquid(this.toStores.FilterAlgaeReactor, ...
                'Flowphase', ... Phase name
                struct('H2O', 234 * oGeo.fVolume / 2,'CO2',0.01,'NO3',0.01),...
                oGeo.fVolume / 2, ... %Phase volume
                293.15,... % Phase temperature
                101325); % Phase pressure
            
            matter.procs.exmes.liquid(oFlow,     'p4');
            matter.procs.exmes.liquid(oFlow,     'p5');
            matter.procs.exmes.liquid(oFlow,     'p6');
            
            % creating the algae phase
            oFiltered = matter.phases.liquid(this.toStores.FilterAlgaeReactor, ...
                'Spirulina', ... Phase name
                struct('Spirulina',3*0.1685), ... Phase contents
                oGeo.fVolume / 2, ... Phase volume
                293.15,... % Phase temperature
                101325); % Phase pressure
            
            
            % Create the according exmes
            % filterports are internal ones for the p2p processor to use.
            matter.procs.exmes.liquid(oFiltered, 'p7');
            matter.procs.exmes.liquid(oFiltered, 'p8');
            matter.procs.exmes.liquid(oFiltered, 'p9');
            matter.procs.exmes.liquid(oFiltered, 'p10');
            
            
            
            
            %oAeration = this.createPhase('air', 1,293,0.5);
            oAeration = matter.phases.gas(this.toStores.FilterAlgaeReactor, ...
                'air', ... Phase name
                struct('O2',21.49/80*100,'N2',70.35/80*100,'CO2',0.09/80*100), ... Phase contents - set by helper
                100, ... Phase volume
                293.15);
            
            matter.procs.exmes.gas(oAeration, 'p1');
            matter.procs.exmes.gas(oAeration, 'p2');
            matter.procs.exmes.gas(oAeration, 'p3');
            matter.procs.exmes.gas(oAeration, 'p12');
            
            
            % controls the temperature and sets the accoring power that is
            % needed to heat/cool the system
            %oTemperatureControl_and_Illumination = components.AlgaeModule.TemperatureControl_and_Illumination(this, 'TemperatureControl_and_Illumination');
            
            this.oProc_Absorber_Algae = components.AlgaeModule.Absorber_Algae(this.toStores.FilterAlgaeReactor, 'filterproc', 'Flowphase.p6', 'Spirulina.p7', 'CO2', 'NO3', 'O2', 0);
            
            
            
            
            
            this.oProc_Absorber_Algae2 = components.AlgaeModule.Absorber_Flowphase(this.toStores.FilterAlgaeReactor, 'filterproc2', 'air.p3', 'Flowphase.p4', 'CO2', 'O2', 0);
            % splits up the components taken from the freshwater phase in
            % the algae phase
            this.oProc_Manip = components.AlgaeModule.O2_Reactor('O2_Reactor', oFiltered, 0);
            
            %gets the produced O2 from the algae phase into the o2 phase
            %within the filter algae reactor store
            this.oProc_Absorber_O2 = components.AlgaeModule.Absorber_O2(this.toStores.FilterAlgaeReactor, 'filterproc1', 'Spirulina.p8', 'air.p12', 'O2', 0);
            
            
            
            
            
            
            
            
            
            
            
            
            % Adding pipes to connect the components
            this.addProcF2F(components.AlgaeModule.Pipe1(this.oData.oMT, 'Pipe_1', 0.5, 0.01));
            this.addProcF2F(components.AlgaeModule.Pipe1(this.oData.oMT, 'Pipe_2', 0.5, 0.01));
            this.addProcF2F(components.AlgaeModule.Pipe1(this.oData.oMT, 'Pipe_3', 0.5, 0.01));
            this.addProcF2F(components.AlgaeModule.Pipe1(this.oData.oMT, 'Pipe_4', 0.5, 0.01));
            this.addProcF2F(components.AlgaeModule.Pipe1(this.oData.oMT, 'Pipe_5', 0.5, 0.01));
            this.addProcF2F(components.AlgaeModule.Pipe1(this.oData.oMT, 'Pipe_6', 0.5, 0.01));
            this.addProcF2F(components.AlgaeModule.Pipe1(this.oData.oMT, 'Pipe_7', 0.5, 0.01));
            this.addProcF2F(components.AlgaeModule.Pipe1(this.oData.oMT, 'Pipe_8', 0.5, 0.01));
            this.addProcF2F(components.AlgaeModule.Pipe1(this.oData.oMT, 'Pipe_9', 0.5, 0.01));
            this.addProcF2F(components.AlgaeModule.Pipe1(this.oData.oMT, 'Pipe_10', 0.5, 0.01));
            this.addProcF2F(components.AlgaeModule.Pipe1(this.oData.oMT, 'Pipe_11', 0.5, 0.01));
            this.addProcF2F(components.AlgaeModule.Pipe1(this.oData.oMT, 'Pipe_12', 0.5, 0.01));
            this.addProcF2F(components.AlgaeModule.Pipe1(this.oData.oMT, 'Pipe_13', 0.5, 0.01));
            this.addProcF2F(components.AlgaeModule.Pipe1(this.oData.oMT, 'Pipe_14', 0.5, 0.01));
            this.addProcF2F(components.AlgaeModule.Pipe1(this.oData.oMT, 'Pipe_15', 0.5, 0.01));
            this.addProcF2F(components.AlgaeModule.Pipe1(this.oData.oMT, 'Pipe_16', 0.5, 0.01));
            
            
            
            % Creating the flowpath between the components
            
            oInputBranch = this.createBranch('FilterAlgaeReactor.p1',  { 'Pipe_1' }, 'InletAir');
            
            oNO3Branch = this.createBranch('FilterAlgaeReactor.p5', { 'Pipe_2' }, 'InletNO3');
            
            oHarvestAlgaeBranch = this.createBranch('FilterAlgaeReactor.p10', { 'Pipe_8'}, 'Outlet_Food_Storage');
            
            oHarvesttoBiomassBranch = this.createBranch('FilterAlgaeReactor.p9', { 'Pipe_14' }, 'Outlet_Biomass_Storage');
            
            oOutputAirBranch = this.createBranch('FilterAlgaeReactor.p2', { 'Pipe_16'}, 'OutletAir');
            
            
            
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
            
            % set the pressure for liquid phases (liquid solver wasn't used
            % when i first adapted this programm
            this.toStores.FilterAlgaeReactor.aoPhases(1,1).setPressure(101325);
            this.toStores.FilterAlgaeReactor.aoPhases(1,2).setPressure(101325);
            
            % adding the branches to the solver
            this.oInputBranch = solver.matter.manual.branch(oInputBranch);
            this.oOutputAirBranch = solver.matter.manual.branch(oOutputAirBranch);
            this.oNO3Branch = solver.matter.manual.branch(oNO3Branch);
            this.oHarvestAlgaeBranch = solver.matter.manual.branch(oHarvestAlgaeBranch);
            this.oHarvesttoBiomassBranch = solver.matter.manual.branch(oHarvesttoBiomassBranch);
            
            
            this.oOutputAirBranch.setFlowRate(0);
            this.oInputBranch.setFlowRate(0); %feed rate for aeration tank chosen so the max aeration rate of 4.2 l/l/min (0.07l/l/s) can be realized
            this.oNO3Branch.setFlowRate(0);%feed rate for aeration tank chosen so the max aeration rate of 4.2 l/l/min (0.07l/l/s) can be realized
            
            
            aoPhases = this.toStores.FilterAlgaeReactor.aoPhases;
            
            tTimeStepProperties.fFixedTimeStep = 15;
            aoPhases(1).setTimeStepProperties(tTimeStepProperties);
            aoPhases(2).setTimeStepProperties(tTimeStepProperties);
            aoPhases(3).setTimeStepProperties(tTimeStepProperties);
            
        end
        function setIfFlows(this, sInlet, sOutlet, sOutlet2, sOutlet3, sInlet2)
            % This function connects the system and subsystem level branches with each other. It
            % uses the connectIF function provided by the matter.container class
            this.connectIF('InletAir',sInlet);
            this.connectIF('OutletAir', sOutlet);
            this.connectIF('Outlet_Food_Storage', sOutlet2);
            this.connectIF('Outlet_Biomass_Storage', sOutlet3);
            this.connectIF('InletNO3', sInlet2);
            
        end
    end
    
    
    
    methods (Access = protected)
        
        function exec(this, ~)
            
            exec@vsys(this);
            %exec method gets called every 30 seconds
            
            
            this.oProc_Absorber_Algae.fPPCO2=this.oParent.toStores.crew_module.aoPhases(1).afPP(11);
            this.oProc_Absorber_Algae.fMassCO2=this.oParent.toStores.crew_module.aoPhases(1).afMass(11);
            this.oProc_Absorber_Algae.fTime=this.oParent.oData.oTimer.fTime;
            
            
            if this.oParent.oParent.oData.oTimer.fTime< 900;
            else
                
                this.setAerationFlowrate();
                this.setHarvestFlowrate();
                this.stopHarvestFlowrate();
                if       this.oParent.toStores.crew_module.aoPhases(1).afPP(11)>140
                    if this.fAerationPower ~= 400
                        this.fAerationPower =400;
                    end;
                else if this.oParent.toStores.crew_module.aoPhases(1).afPP(11)<40
                        if this.fAerationPower ~= 200
                            this.fAerationPower=200;
                        end;
                    end
                end
            end
        end
        
        function setAerationFlowrate(this)
            if  this.fAerationPower == 100
                
                this.oOutputAirBranch.setFlowRate((1-this.fHarvest)*(0.1+this.oProc_Absorber_O2.fFlowRate-this.oProc_Absorber_Algae.fFlowRate*this.oProc_Absorber_Algae.arExtractPartials(11)));
                this.oInputBranch.setFlowRate(-0.1);
                this.oNO3Branch.setFlowRate(-this.oProc_Absorber_Algae.fFlowRate*this.oProc_Absorber_Algae.arExtractPartials(13));
            else
            end
            if  this.fAerationPower == 200
                
                this.oOutputAirBranch.setFlowRate((1-this.fHarvest)*(0.35+this.oProc_Absorber_O2.fFlowRate-this.oProc_Absorber_Algae.fFlowRate*this.oProc_Absorber_Algae.arExtractPartials(11)));
                this.oInputBranch.setFlowRate((1-this.fHarvest)*-0.35);
                this.oNO3Branch.setFlowRate(-this.oProc_Absorber_Algae.fFlowRate*this.oProc_Absorber_Algae.arExtractPartials(13));
            else
            end
            if  this.fAerationPower == 400
                
                this.oOutputAirBranch.setFlowRate((1-this.fHarvest)*(0.7+this.oProc_Absorber_O2.fFlowRate-this.oProc_Absorber_Algae.fFlowRate*this.oProc_Absorber_Algae.arExtractPartials(11)));
                this.oInputBranch.setFlowRate(-0.7*(1-this.fHarvest));
                this.oNO3Branch.setFlowRate(-this.oProc_Absorber_Algae.fFlowRate*this.oProc_Absorber_Algae.arExtractPartials(13));
            else
            end
        end
        
        function setHarvestFlowrate(this)
            if this.oProc_Absorber_Algae.fDilution >= 12
                this.fHarvest = 1; %on
                this.fHarvestFlowRate=0.01;
                %this.oHarvestAlgaeBranch.setFlowRate(0.8*this.fHarvestFlowRate);
                this.oInputBranch.setFlowRate(0);
                this.oOutputAirBranch.setFlowRate(0);
                %this.oHarvesttoBiomassBranch.setFlowRate(0.2*this.fHarvestFlowRate);
                
                disp('Harvest in process');
            end
            if this.fHarvest ~=0
                if this.oParent.toStores.Food_Storage.aoPhases(1).fMass <=1
                    this.oHarvestAlgaeBranch.setFlowRate(this.fHarvestFlowRate);
                    this.oHarvesttoBiomassBranch.setFlowRate(0);
                else
                    this.oHarvestAlgaeBranch.setFlowRate(0.2*this.fHarvestFlowRate);
                    this.oHarvesttoBiomassBranch.setFlowRate(0.8*this.fHarvestFlowRate);
                end;
            end;
        end
        
        function stopHarvestFlowrate(this)
            if  this.oProc_Absorber_Algae.fDilution < 6
                this.fHarvest = 0; %off
                this.oHarvestAlgaeBranch.setFlowRate(0);
                this.oHarvesttoBiomassBranch.setFlowRate(0);
                %disp('Harvest finished');
            end
        end
        
    end
end



