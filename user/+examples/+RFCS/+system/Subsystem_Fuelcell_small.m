classdef Subsystem_Fuelcell_small < vsys
    %PEM- Fuel cell build with 2 gaschanals and a membrane in between
    
    properties (SetAccess = protected, GetAccess = public)
        %number of cells of the fuelcell stack
        iCells = 30;
        
        % Last time at which the voltage calculation function was executed
        % in seconds
        fLastVoltageCalculation = 0;
        
        fCurrentVoltage = 0;
        
        fEfficiency = 1; %efficienty
        heat=0; %heat produced by the cell
        
    end
    
    
    properties (SetAccess=public, GetAccess = public)
        
        
        fI=0; %stack current
        fVoltage=20; %stack voltage
        fTemperature; %temperatur of the fuel cell stack
        fPower=0; %electric power of the fuel cell stack
        
        told=0;
        Uo=1;
    end
    
    
    methods
        function this = Subsystem_Fuelcell_small(oParent, sName)
            
            this@vsys(oParent, sName, 30);
            
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
            
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            %stores and phases--------------------------------------------------------
            
            
            fInitialTemperature = 293.15; %initial Temperatur of all phases of the fuelcell
            
            %Creating gaschanals H2
            %IN
            matter.store(this, 'gaschanal_in_h2', 0.15);
            this.oFuel_in=matter.phases.gas(this.toStores.gaschanal_in_h2, 'fuel', struct('H2', 0.015,'H2O',0.0025), 0.1, this.fT_init);
            matter.phases.gas(this.toStores.gaschanal_in_h2, 'H2_absorb', struct('H2', 0.015), 0.05, this.fT_init);
            
            
            
            
            %creating gaschanal O2
            %IN
            matter.store(this, 'gaschanal_in_o2', 0.15);
            
            matter.phases.gas(this.toStores.gaschanal_in_o2, 'O2_H2O', struct('O2', 0.25,'H2O',0.0025), 1, this.fT_init);
            matter.phases.gas(this.toStores.gaschanal_in_o2, 'O2_absorb', struct('O2', 0.25), 1, this.fT_init);
            
            
            
            % Creating membrane
            matter.store(this, 'membrane', 0.3); %0.0015
            
            this.odiverses=matter.phases.gas(this.toStores.membrane,'diverses', struct('O2', 0.25,'H2', 0.015,'H2O',0.005), 1, this.fT_init);
            this.oabsorberPhase=matter.phases.absorber(this.toStores.membrane, 'H2O_absorber', struct('H2O',0.5), this.fT_init,'liquid','H2O');
            matter.phases.liquid(this.toStores.membrane,'H2O_react', struct('H2O',1),0.01, 330);
            
            
            % processors-----------------------------------------------------------------------
            
            %gaschanal H2 in
            
            %fuel in
            matter.procs.exmes.gas(this.toStores.gaschanal_in_h2.toPhases.fuel, 'Fuel_in');
            %p2p to absorb pure h2 out
            matter.procs.exmes.gas(this.toStores.gaschanal_in_h2.toPhases.fuel, 'p2p_out');
            %p2p to absorb pure h2 in
            matter.procs.exmes.gas(this.toStores.gaschanal_in_h2.toPhases.H2_absorb, 'p2p_in');
            
            %massflow of h2 to the membrane
            matter.procs.exmes.gas(this.toStores.gaschanal_in_h2.toPhases.H2_absorb, 'massflow_h2');
            %output for fuel and gaswater
            matter.procs.exmes.gas(this.toStores.gaschanal_in_h2.toPhases.fuel, 'fuel_out_out');
            %input of water
            matter.procs.exmes.gas(this.toStores.gaschanal_in_h2.toPhases.fuel, 'water_in_h2');
            
            %gaschanal O2 in
            
            %air in
            matter.procs.exmes.gas(this.toStores.gaschanal_in_o2.toPhases.O2_H2O, 'o2_in');
            %p2p to absorb pure o2 out
            matter.procs.exmes.gas(this.toStores.gaschanal_in_o2.toPhases.O2_H2O, 'p2p_out');
            %p2p to absorb pure o2 in
            matter.procs.exmes.gas(this.toStores.gaschanal_in_o2.toPhases.O2_absorb, 'p2p_in');
            
            %massestrom to the membrane
            matter.procs.exmes.gas(this.toStores.gaschanal_in_o2.toPhases.O2_absorb, 'massflow_o2');
            %input of water
            matter.procs.exmes.gas(this.toStores.gaschanal_in_o2.toPhases.O2_H2O, 'o2_out_out');
            %output of oxygen an gas water
            matter.procs.exmes.gas(this.toStores.gaschanal_in_o2.toPhases.O2_H2O, 'water_in_o2');
            
            %membrane
            
            %massflow h2 to membrane
            matter.procs.exmes.gas(this.toStores.membrane.toPhases.diverses, 'membrane_h2_in');
            %massflow O2 to membrane
            matter.procs.exmes.gas(this.toStores.membrane.toPhases.diverses, 'membrane_o2_in');
            %p2p
            matter.procs.exmes.gas(this.toStores.membrane.toPhases.diverses, 'gas_water_out');
            
            %p2p
            matter.procs.exmes.absorber(this.toStores.membrane.toPhases.H2O_absorber, 'absorber_in');
            matter.procs.exmes.absorber(this.toStores.membrane.toPhases.H2O_absorber, 'absorber_out');
            
            %p2p
            matter.procs.exmes.liquid(this.toStores.membrane.toPhases.H2O_react, 'liquid_water_in');
            
            
            %membrane to gaschanals
            %product water to gaschanal h2
            matter.procs.exmes.liquid(this.toStores.membrane.toPhases.H2O_react, 'membrane_to_Gaskanal_out_o2');
            %product water to gaschanal o2
            matter.procs.exmes.liquid(this.toStores.membrane.toPhases.H2O_react, 'membrane_to_Gaskanal_out_h2');
            
            %react water out
            matter.procs.exmes.liquid(this.toStores.membrane.toPhases.H2O_react, 'liquid_water_out');
            
            %cooling store
            matter.procs.exmes.liquid(this.toStores.membrane.toPhases.H2O_react, 'cooling_in');
            matter.procs.exmes.liquid(this.toStores.membrane.toPhases.H2O_react, 'cooling_out');
            
            
            %components-----------------------------------------------------------------------------------------------------
            
            %pipes
            components.pipe(this, 'Pipe_h2', 1.5, 0.003);
            components.pipe(this, 'Pipe_o2', 1.5, 0.008);
            
            components.pipe(this, 'Pipe_p1', 1, 0.008);
            components.pipe(this, 'Pipe_p2', 1, 0.008);
            
            components.pipe(this, 'Pipe_p3', 1, 0.002);
            components.pipe(this, 'Pipe_p4', 1, 0.002);
            %branches----------------------------------------------------------------------------------------------------
            
            %form gaskanal to membrane
            matter.branch(this, 'gaschanal_in_h2.massflow_h2', {}, 'membrane.membrane_h2_in', 'H2_Diffusion');
            matter.branch(this, 'gaschanal_in_o2.massflow_o2', {}, 'membrane.membrane_o2_in', 'O2_Diffusion');
            
            %from membrane to gaschanal h2
            matter.branch(this, 'membrane.membrane_to_Gaskanal_out_h2', {}, 'gaschanal_in_h2.water_in_h2', 'H2_Back_Diffusion');
            
            %form membrane to gaschanal o2
            matter.branch(this, 'membrane.membrane_to_Gaskanal_out_o2', {}, 'gaschanal_in_o2.water_in_o2', 'process_water');
            
            
            matter.branch(this, 'gaschanal_in_h2.Fuel_in', {}, 'Inlet1'); %connection Subsystem input   manual
            matter.branch(this, 'gaschanal_in_o2.o2_in', {}, 'Inlet2'); %connection Subsystem input  manual
            
            matter.branch(this, 'gaschanal_in_h2.fuel_out_out', {}, 'Outlet1'); %connection Subsystem output  iterative
            matter.branch(this, 'gaschanal_in_o2.o2_out_out', {}, 'Outlet2'); %connection Subsystem output    iterative
            
            matter.branch(this, 'membrane.liquid_water_out', {}, 'Outlet3'); %connection Subsystem output    manual
            
            
            matter.branch(this, 'membrane.cooling_out', {}, 'Outlet_cooling');%cooling circle extern manual
            matter.branch(this, 'membrane.cooling_in', {}, 'Inlet_cooling'); %cooling circle extern  manual
            %manipulator---------------------------------------------------------------------------------------
            
            %Creating the manipulator
            %property to get access to the variables
            this.oManipulator=ebto.RFCS.components.water_reaction('water_reaction', this.oabsorberPhase);
            
            
            % p2p --------------------------------
            
            % p2p_watertransportt in membrane
            this.P2P_1=ebto.RFCS.components.Fuel_transport(this.toStores.membrane, 'Fuel_transport',  'diverses.gas_water_out','H2O_absorber.absorber_in');
            
            %p2p watertransport vaporation in gaschanal O2
            ebto.RFCS.components.water_output(this.toStores.membrane,'water_output', 'H2O_absorber.absorber_out', 'H2O_react.liquid_water_in');
            
            %p2p h2 absorbtion gaschanal
            ebto.RFCS.components.H2_Absorber_gaschanal(this.toStores.gaschanal_in_h2,'H2_Absorber_gaschanal', 'fuel.p2p_out', 'H2_absorb.p2p_in');
            
            %p2p o2 absorbtion gaschanal
            ebto.RFCS.components.O2_Absorber_gaschanal(this.toStores.gaschanal_in_o2,'O2_Absorber_gaschanal', 'O2_H2O.p2p_out', 'O2_absorb.p2p_in');
            
            
            
        end
        
        function setIfFlows(this, sInlet1,sInlet2, sOutlet1,sOutlet2,sOutlet3,sInlet_cooling,sOutlet_cooling)
            % This function connects the system and subsystem level branches with each other. It
            % uses the connectIF function provided by the matter.container class
            
            this.connectIF('Inlet1',  sInlet1);
            this.connectIF('Inlet2',  sInlet2);
            this.connectIF('Outlet1', sOutlet1);
            this.connectIF('Outlet2', sOutlet2);
            this.connectIF('Outlet3', sOutlet3);
            this.connectIF('Outlet_cooling', sOutlet_cooling);
            this.connectIF('Inlet_cooling', sInlet_cooling);
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            
            
            %add solver: one iterative solver for each gaschanal
            
            solver.matter.iterative.branch(this.aoBranches(5));
            solver.matter.iterative.branch(this.aoBranches(6));
            solver.matter.iterative.branch(this.aoBranches(7));
            solver.matter.iterative.branch(this.aoBranches(8));
            
            %            solver.matter.iterative.branch(this.aoBranches(3));
            %            solver.matter.iterative.branch(this.aoBranches(4));
            
            %manual solver
            this.oBranch1=solver.matter.manual.branch(this.aoBranches(1));
            this.oBranch2=solver.matter.manual.branch(this.aoBranches(2));
            this.oBranch3=solver.matter.manual.branch(this.aoBranches(3));
            this.oBranch4=solver.matter.manual.branch(this.aoBranches(4));
            this.oBranch5=solver.matter.manual.branch(this.aoBranches(9));
            this.ocoolBranch1=solver.matter.manual.branch(this.aoBranches(10));
            this.ocoolBranch2=solver.matter.manual.branch(this.aoBranches(11));
            
            
            
        end
        
        %own methods of the fuel cell------------------------------------
        
        % TO DO: Replace with heat source
        function calculate_inner_energy_change(this)
            %calculate the heating power of the fuelcell
            %the produced heat changes the inner energy of the liquid water phase
            fTimeStep=this.oTimer.fTime-this.told;
            
            I=this.fI;  %current of the cell
            
            %efficiency is calculatet by using the current voltage of the single cell
            % and the open circuit voltage regarding to current pressure and
            % temperature (fVoltage = Stack voltage)
            this.eta=(this.fVoltage/this.n)/this.Uo;
            %this is the heat that the cell produces
            this.heat=I*this.fVoltage*(1-this.fEfficiency);
            
            %convert the power to the amaount of energy between to function calls
            q=this.heat*fTimeStep;
            
            %set inner energy change
            this.toStores.membrane.toPhases.H2O_react.changeInnerEnergy(q);
            %Temperature of the membrane phase = Temperature of the fuelcell
            this.fTemperature=this.toStores.membrane.toPhases.H2O_react.fTemperature;
            
            this.told=this.oTimer.fTime;
            
        end
        
        
        
        function calculate_voltage(this)
            
            
            
            % calculate the voltage of the fuel cell
            % depending on input partial-pressure temperature
            % current and internal resistance
            R=8.314459; %gaskonstant J/(mol*K)
            T=this.fTemperature;
            fFaraday=96485.3365; %As/mol
            
            I=this.fI;
            
            I_limit=100; %max current throw the membrane
            I_o=0.01;  %change current
            
            %this are usual default values
            a=0.4;     %activation coefficient
            beta=0.8;  %diffusion coefficient
            
            k=0.00085; %linearisation faktor for gibbs energy
            %(do to use values from mattertable)
            
            %membrane
            lamda=14; %water content of the membrane 0-20 (no dynamic effects at the moment)
            A=250;   %area of the membrane on cm^2
            l=2*10^-4; %thickness of the membrane in cm
            
            %calculating the resistence of the membrane
            Rm=l/(A*(0.005139*lamda+0.00326)*exp(1267*(1/303-1/T)));
            
            %timeconstant of the outpur capasity
            ftau=2;
            %get the partialpressure and massflow of the input phases:
            [ afPartialPressures_h2 ] = getPartialPressures(this.toStores.gaschanal_in_h2.toPhases.fuel);
            [ afPartialPressures_o2 ] = getPartialPressures(this.toStores.gaschanal_in_o2.toPhases.O2_H2O);
            
            fPressure_H2=afPartialPressures_h2(this.oMT.tiN2I.H2);
            fPressure_O2=afPartialPressures_o2(this.oMT.tiN2I.O2);
            
            %calculate the static stack voltage
            if I>0
                Vo=this.n*(1.23-k*(T-298)+R*T/2/fFaraday*log(fPressure_H2*sqrt(fPressure_O2))-R*T/2/fFaraday/a*log(I/I_o)-Rm*I-R*T/2/fFaraday/beta*log(1+I/I_limit));
            else
                %another function for the case i==0 because of the log()
                Vo=this.n*(1.23-k*(T-298)+R*T/2/fFaraday*log(fPressure_H2*sqrt(fPressure_O2)));
            end
            
            %zero potential of the cell
            this.Uo=1.23-k*(T-298)+R*T/2/fFaraday*log(fPressure_H2*sqrt(fPressure_O2));
            
            %current timestep
            h=this.oTimer.fTime-this.lastexec;
            if h<1
                this.fCurrentVoltage=this.fCurrentVoltage+h*(Vo-this.fCurrentVoltage)*ftau; %euler eqation
            end
            
            this.fVoltage=this.fCurrentVoltage; %stack voltage
            
            this.lastexec=this.oTimer.fTime;
            
            
        end
        
        
        function calculate_current(this)
            
            % no very important method :)
            
            %to iplement dynamics of the electrical load
            %for the moment you have to set the current from the exec function
            %of the main system
            
            %i tryed to set the electrical power instead of the current and
            %calculate the current depending on U(i) and P(t), but this got
            %unstable
            
        end
        
    end
    
    
    methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            
            %set the manual solver for the cooling circle
            %this side of the heat exchanger the flowrate is always the same
            % the other side of the heat exchanger has a control logic
            
            this.ocoolBranch1.setFlowRate(0.1);
            this.ocoolBranch2.setFlowRate(-0.1);
            
        end
        
    end
    
    
    
    
    
end

