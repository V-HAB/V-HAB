classdef FuelCell < vsys
    %PEM- Fuel cell build with 2 gaschanals and a membrane in between
    
    properties (SetAccess = protected, GetAccess = public)
        %number of cells of the fuelcell stack
        iCells = 30;
        
        % Last time at which the voltage calculation function was executed
        % in seconds
        fLastVoltageCalculation = 0;
        
        fCurrentVoltage = 0;
        
        % This property is used to store the current efficiency value of
        % the fuel cell. The efficiency is calculated dynamically within
        % the calculate_Voltage function
        rEfficiency = 1; %efficienty
        
        
        fStackCurrent = 0; % A
        fStackVoltage = 20; % V
        fTemperature; %temperatur of the fuel cell stack
        fPower = 0; %electric power of the fuel cell stack
        
        fStackZeroPotential = 1;
    end
    
    
    methods
        function this = FuelCell(oParent, sName, iCells)
            
            this@vsys(oParent, sName, 30);
            
            this.iCells = iCells;
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
            
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            %stores and phases--------------------------------------------------------
            
            
            fInitialTemperature = 293.15; %initial Temperatur of all phases of the fuelcell
            
            % The fuel cell is created as one store, containing the
            % different parts of the fuel cell. The store is therefore
            % split into different phases, to represent the different
            % components (H2 Channel, O2 Channel, Membrane, Cooling System)
            matter.store(this, 'FuelCell', 0.5);
            
            oH2 =       this.toStores.FuelCell.createPhase(  'gas', 'flow', 'H2_Channel',   0.05, struct('H2', 1e5),  fInitialTemperature, 0.8);
            oO2 =       this.toStores.FuelCell.createPhase(  'gas', 'flow', 'O2_Channel',   0.05, struct('O2', 1e5),  fInitialTemperature, 0.8);
            
            oMembrane = this.toStores.FuelCell.createPhase(  'gas',         'Membrane',     0.3, struct('O2', 0.5e5, 'H2', 0.5e5),  fInitialTemperature, 0.5);
            
            oCooling =  this.toStores.FuelCell.createPhase(  'liquid',      'CoolingSystem',0.1, struct('H2O', 1),  fInitialTemperature, 1e5);
            
            % pipes
            components.matter.pipe(this, 'Pipe_H2_In',          1.5, 0.003);
            components.matter.pipe(this, 'Pipe_H2_Out',         1.5, 0.003);
            components.matter.pipe(this, 'Pipe_O2_In',          1.5, 0.003);
            components.matter.pipe(this, 'Pipe_O2_Out',         1.5, 0.003);
            components.matter.pipe(this, 'Pipe_Cooling_In',     1.5, 0.003);
            components.matter.pipe(this, 'Pipe_Cooling_Out',    1.5, 0.003);
            
            % branches
            matter.branch(this, oH2,        {'Pipe_H2_In'},         'H2_Inlet',         'H2_inlet');
            matter.branch(this, oH2,        {'Pipe_H2_Out'},        'H2_Outlet',        'H2_Outlet');
            
            matter.branch(this, oO2,        {'Pipe_O2_In'},         'O2_Inlet',         'O2_inlet');
            matter.branch(this, oO2,        {'Pipe_O2_Out'},        'O2_Outlet',        'O2_Outlet');
            
            matter.branch(this, oCooling,   {'Pipe_Cooling_In'},    'Cooling_Inlet',  	'Cooling_inlet');
            matter.branch(this, oCooling,   {'Pipe_Cooling_Out'},   'Coooling_Outlet',	'Cooling_Outlet');
            
            % adding the fuel cell reaction manip
            components.matter.FuelCell.components.FuelCellReaction('FuelCellReaction', oMembrane);
            
            components.matter.P2Ps.ManualP2P(this.toStores.FuelCell, 'H2_to_Membrane',  oH2,        oMembrane);
            components.matter.P2Ps.ManualP2P(this.toStores.FuelCell, 'Membrane_to_H2',  oMembrane,  oH2);
            components.matter.P2Ps.ManualP2P(this.toStores.FuelCell, 'O2_to_Membrane',  oO2,        oMembrane);
            components.matter.P2Ps.ManualP2P(this.toStores.FuelCell, 'Membrane_to_O2',  oMembrane,  oO2);
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
        
        function calculate_voltage(this)
            
            
            
            % calculate the voltage of the fuel cell
            % depending on input partial-pressure temperature
            % current and internal resistance
            R=8.314459; %gaskonstant J/(mol*K)
            T=this.fTemperature;
            fFaraday=96485.3365; %As/mol
            
            I=this.fStackCurrent;
            
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
                Vo=this.iCells*(1.23-k*(T-298)+R*T/2/fFaraday*log(fPressure_H2*sqrt(fPressure_O2))-R*T/2/fFaraday/a*log(I/I_o)-Rm*I-R*T/2/fFaraday/beta*log(1+I/I_limit));
            else
                %another function for the case i==0 because of the log()
                Vo=this.iCells*(1.23-k*(T-298)+R*T/2/fFaraday*log(fPressure_H2*sqrt(fPressure_O2)));
            end
            
            %zero potential of the cell
            this.fStackZeroPotential=1.23-k*(T-298)+R*T/2/fFaraday*log(fPressure_H2*sqrt(fPressure_O2));
            
            %current timestep
            h=this.oTimer.fTime-this.lastexec;
            if h<1
                this.fCurrentVoltage=this.fCurrentVoltage+h*(Vo-this.fCurrentVoltage)*ftau; %euler eqation
            end
            
            this.fStackVoltage=this.fCurrentVoltage; %stack voltage
            
            % efficiency is calculatet by using the current voltage of the single cell
            % and the open circuit voltage regarding to current pressure and
            % temperature (fVoltage = Stack voltage)
            this.rEfficiency = (this.fStackVoltage/this.iCells)/this.fStackZeroPotential;
            % 
            fHeatFlow = I*this.fStackVoltage*(1-this.rEfficiency);
            
            % now we set the calculated heat flow to the corresponding heat
            % source within the system. It is assumed that the heat is
            % generated in the water phase of the fuel cell
            asdasd! 
            
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

