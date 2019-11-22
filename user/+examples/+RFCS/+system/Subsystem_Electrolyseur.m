classdef Subsystem_Electrolyseur < vsys
    
    %model of a electrolyseur
    %input water
    %output h2
    %output o2
    %in and output coolingsystem
    
    %calculates the required Voltage to cleave the water depending on
    %pressure and Temperatur
    %as Input set the fPower Property.
    properties
        fI=0; %current
        uz=1.48; %cellvoltage
        fVoltage=12; %stack voltage
        oManipulator %manipulator for the chemical reaction
        fPower=0;%power of the stack
        fTemperature=290; %temperatur of the stack
        fT_init=273.15+20; %initial temperatur of the stack
        Number_cells=100;  %number of cells
        heat; %heat produced by the electrolyseur
        
        
        fPipeLength   = 3;
        fPipeDiameter = 0.002;
        oCoolingbranch1;
        oCoolingbranch2;
        oCoolingbranch3;
        oCoolingbranch4;
        water_pump;
        pipe;
        told=0;
        
        
        ch2;
        co2;
    end
    
    methods
        function this = Subsystem_Electrolyseur(oParent, sName)
            
            this@vsys(oParent, sName, 30);
            eval(this.oRoot.oCfgParams.configCode(this));
            
            
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %stores and phases
            
            % Membrane
            mO_mh2=7.9367;
            matter.store(this, 'membrane', 0.02);
            oWaterPhase     = matter.phases.liquid(this.toStores.membrane, 'water', struct('H2O',0.5), 330,101300);
            oAbsorberPhase  = matter.phases.mixture(this.toStores.membrane, 'membrane', 'solid', struct('H2O',0.5,'H2',0.00,'O2',0.00), this.fT_init, 1e5);
            oGasPhase       = matter.phases.gas(this.toStores.membrane, 'gas_output', struct('H2',0,'O2',0),1,this.fT_init);
            
            %Chanal
            matter.store(this, 'Chanal', 0.02);
            matter.phases.gas(this.toStores.Chanal, 'H2O2', struct('H2',0.001,'O2',0.001*mO_mh2),1, this.fT_init);
            matter.phases.gas(this.toStores.Chanal, 'O2', struct('O2',0.025),1, this.fT_init);
            matter.phases.gas(this.toStores.Chanal, 'H2', struct('H2',0.002),1, this.fT_init);
            
            %exme
            %Membrane
            matter.procs.exmes.liquid(oWaterPhase, 'M_Port_1'); %liquid in
            
            matter.procs.exmes.liquid(oWaterPhase, 'M_Port_2'); %liquid water out p2p2
            matter.procs.exmes.mixture(oAbsorberPhase, 'M_Port_3'); %liquid water in p2p
            
            matter.procs.exmes.mixture(oAbsorberPhase, 'M_Port_4'); %gas out p2p
            matter.procs.exmes.gas(oGasPhase, 'M_Port_5');%gas in p2p
            
            matter.procs.exmes.gas(oGasPhase, 'M_Port_6');%gas to the gaschanal
            
            matter.procs.exmes.liquid(oWaterPhase, 'M_Port_7'); %cooling circle
            matter.procs.exmes.liquid(oWaterPhase, 'M_Port_8'); %cooling circle
            
            
            
            %Chanal
            
            matter.procs.exmes.gas(this.toStores.Chanal.toPhases.H2O2, 'C_Port_1');%gas form membrane
            
            %h2 absorber
            matter.procs.exmes.gas(this.toStores.Chanal.toPhases.H2O2, 'C_Port_2');
            matter.procs.exmes.gas(this.toStores.Chanal.toPhases.O2, 'C_Port_3');
            %h2 out
            matter.procs.exmes.gas(this.toStores.Chanal.toPhases.O2, 'C_Port_4');
            
            %o2 absorber
            matter.procs.exmes.gas(this.toStores.Chanal.toPhases.H2O2, 'C_Port_5');
            matter.procs.exmes.gas(this.toStores.Chanal.toPhases.H2, 'C_Port_6');
            %o2 out
            matter.procs.exmes.gas(this.toStores.Chanal.toPhases.H2, 'C_Port_7');
            
            
            
            %components
            components.matter.pipe(this, 'Pipe_1', this.fPipeLength, this.fPipeDiameter);
            
            
            %Branches
            matter.branch(this, 'membrane.M_Port_6',{}, 'Chanal.C_Port_1'); %intern
            
            
            matter.branch(this, 'membrane.M_Port_1', {}, 'Inlet'); %connection Subsystem
            matter.branch(this, 'Chanal.C_Port_7', {}, 'Outlet1');%connection Subsystem
            matter.branch(this, 'Chanal.C_Port_4', {}, 'Outlet2');%connection Subsystem
            
            matter.branch(this, 'membrane.M_Port_7', {}, 'Outlet_cooling');%cooling circle extern
            matter.branch(this, 'membrane.M_Port_8', {}, 'Inlet_cooling'); %cooling circle extern
            
            %maipulator
            this.oManipulator = examples.RFCS.components.cleavage('cleavage', oAbsorberPhase);
            
            
            %p2p
            examples.RFCS.components.H2O2_transport(this.toStores.membrane, 'H2O2_transport','diverses.M_Port_4','gas_output.M_Port_5');
            examples.RFCS.components.H2O_transport(this.toStores.membrane, 'H2O_transport','water.M_Port_2','diverses.M_Port_3');
            examples.RFCS.components.O2_Absorber(this.toStores.Chanal, 'O2_Absorber','H2O2.C_Port_2','O2.C_Port_3');
            examples.RFCS.components.H2_Absorber(this.toStores.Chanal, 'H2_Absorber','H2O2.C_Port_5','H2.C_Port_6');
            
        end
        
        function setIfFlows(this, sInlet, sOutlet1,sOutlet2,sInlet_cooling,sOutlet_cooling)
            % This function connects the system and subsystem level branches with each other. It
            % uses the connectIF function provided by the matter.container class
            
            this.connectIF('Inlet',  sInlet);
            this.connectIF('Outlet1', sOutlet1);
            this.connectIF('Outlet2', sOutlet2);
            this.connectIF('Outlet_cooling', sOutlet_cooling);
            this.connectIF('Inlet_cooling', sInlet_cooling);
            
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            %branche between the membrane store and the gaschanal store
            %
            this.pipe=solver.matter.manual.branch(this.aoBranches(1));
            
            %Connection Subsystem
            %Supplys the membrane with new water
            %do to could set this branch depending on the grade of saturation level
            %at the moment: the amount that is used during the reaction gets in
            this.water_pump=solver.matter.manual.branch(this.aoBranches(2));
            
            %i changed here between iterativ and manual Branches
            %when the electrolyseur gets power gaspressure increases
            %at the output. used a compressor or fan to pump it in a store
            solver.matter.iterative.branch(this.aoBranches(3)); %extern
            solver.matter.iterative.branch(this.aoBranches(4)); %extern
            
            %            this.ch2=solver.matter.manual.branch(this.aoBranches(3)); %extern
            %            this.co2=solver.matter.manual.branch(this.aoBranches(4)); %extern
            
            this.oCoolingbranch1=solver.matter.manual.branch(this.aoBranches(5));
            this.oCoolingbranch2=solver.matter.manual.branch(this.aoBranches(6));
            
            
            
        end
        
        function calculate_voltage(this)
            % calculate the voltage of the electrolyseur
            
            R=8.314459; %gaskonstant J/(mol*K)
            T=this.toStores.membrane.toPhases.water.fTemperature; %temperature of the water phase
            fFaraday=96485.3365;
            n=this.Number_cells; %nummer of cells
            
            P=this.fPower;    %input Power
            I=P/n/this.uz;    %current per cell
            
            this.fI=I;
            
            %Partialpressure of H2 and O2 in the output phase
            fPressure_H2=this.toStores.Chanal.toPhases.H2.fPressure;
            fPressure_O2=this.toStores.Chanal.toPhases.O2.fPressure;
            
            %water concentration in the reacting phase
            %i wanted to calculate a saturation level of the membrane
            % not used for further equations
            fc=this.toStores.membrane.toPhases.diverses.afMass(this.oMT.tiN2I.H2O)/...
                this.toStores.membrane.toPhases.diverses.fMass;
            
            %get these values from a datasheet
            I_o=0.01; %exchange current
            I_limit=1000; %max current
            
            k=0.00085; %linerasiation factor for gibbs energy
            
            %membrane
            lamda=14; %water content of the membrane 0-14
            A=25; %area of the membrane in cm^2
            l=2*10^-4; %thickness of the membrane
            
            a=0.4; %exchange coefficient
            beta=0.8; %diffusion coefficient
            
            Rm=l/(A*(0.005139*lamda+0.00326)*exp(1267*(1/303-1/T))); %membrane resistentece of one cell
            %another case for p==0 and I==0 because of the log()
            if fPressure_H2>0
                if I>0
                    Vo=1.23+k*(T-298)+R*T/2/fFaraday*log(fPressure_H2*sqrt(fPressure_O2))+R*T/2/fFaraday/a*log(I/I_o)+this.Number_cells*Rm*I+R*T/2/fFaraday/beta*log(1+I/I_limit);
                    
                else
                    Vo=1.48; %default value for starting
                end
            else
                Vo=1.48;
            end
            this.uz=Vo; %cellvoltage
        end
        
        function calculate_inner_energy_change(this)
            %calculate the heating power of the fuelcell
            
            fTimeStep=this.oTimer.fTime-this.told; %current time step of the funktion
            
            
            rEta=1.48/this.uz; %Urev/Uze efficiency regarding to the thermal neutral voltage
            
            this.heat=this.fPower*(1-rEta);%
            
            
            if this.heat>0
                
                q=this.heat*fTimeStep;  %amaount of energy change during this timestep
            else
                q=0; %theoretical could be endotherm
            end
            
            
            %set inner energy change
            this.toStores.membrane.toPhases.water.changeInnerEnergy(q);
            %Temperature of the membrane phase = Temperature of the fuelcell
            this.fTemperature=this.toStores.membrane.toPhases.water.fTemperature;
            this.told=this.oTimer.fTime;
            
        end
        
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            
            %set cooling branches
            this.oCoolingbranch1.setFlowRate(0.1); %intern circle
            this.oCoolingbranch2.setFlowRate(-0.1); %intern circle
            
            %replace the used water
            this.water_pump.setFlowRate(-this.oManipulator.fMassH2O);
            
            
            
        end
        
    end
    
end

