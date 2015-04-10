classdef TemperatureControl_and_Illumination < vsys
  
    
    properties
        fPower = 2000;
        fAerationPower = 0;
        fP_pump = 200; %W
        fT_soll = 273+35; % K
        fm=1.425; %kg (/ min)
        fc_spec_H2O = 4182.6/60; % J/K kg ---> W*min/K kg
        fP_fill = 0;
        fP_harv = 0;
        fP_total = 0;
        fQ_out = 0;   
            
        
        fFlagTemp = 0;
    end
    
    methods
        function this = TemperatureControl_and_Illumination(oParent, sName)
            this@vsys(oParent, sName, 60);
            
            
      this.oParent.toChildren.PowerControl.fPower;
      
      
      
        
         
            
                
                
 %% Temp control
        
       % code taken from old PBR simulation mostly self explanatory
       % needs to be adapted into the thermal solver
       % which was added when i finished my thesis
        
        
        
        if this.fFlagTemp == 0
            
            
            x=0;
            y=0;
            
            
            Q_FW = 0;
            P_fill = 0;
            P_harv = 0;
            Q_el_lamp =2*1500; %W
            Q_heat = 0; % W
            Q_IR = 0.75*Q_el_lamp; %W 25% in Licht umgesetzt
            Q_cool=0;
            %constants
            boltz=5.6704E-8; %W/(m²K^4)
            
            c_spec_H2O = 4182.6/60; % J/K kg ---> W*min/K kg
            c_spec_Al  = 9000.0/60; % J/K kg ---> W*min/K kg
            c_spec_Air  = 1010.0/60; % J/K kg ---> W*min/K kg
            c_spec_Lamp  = 1001.2/60; % J/K kg ---> W*min/K kg Mischung aus Luft und Wolfram c_spec_Wolfram = 130 J/K kg
            
            rho_H2O = 1000; % kg/m³
            rho_Al = 2700;  % kg/m³
            rho_Air = 1.29; %  kg/m³
            rho_Lamp = 194.2; %  kg/m³  Mischung aus Luft und Wolfram rho_Wolfram = 19300 kg/m³
            
            dyn_visc_Air = 1.71E-5; % kg/m s --> 1.026E-3; % kg/m min --> 217.1; % muPa*s
            spec_cond_Air = 0.025; % W/K m
            
            % Node volumes
            
            V(1)=0.50; % m³ % fresh water tank
            
            % d_tank = 0.5; % m
            % h_tank = 1; % m
            
            %         d_tank = 3; % m
            %         h_tank = 3; % m
            
            
            % obj.A(2) = 20*2 * pi*d_tank^2/4; %m²   nur an den bodenflächen diemantelfläche ist von lampen umgeben  Am= pi*d_tank*h_tank
            A(2) = 2*3*0.026+2*3*0.026;
            % obj.V(2)=0.8*pi*d_tank^2/4*h_tank; % m³ % bioreactor 80% full
            V(2) = 0.8*3*3*0.026;
            V(3)= 1; % m³ % environment module
            
            % obj.A(1)= pi*d_tank*h_tank; %Mantelfläche
            A(1)= 2*3*3;
            V(4)= 0.1; % m³
            
            
            % air velocity
            
            velocity_air = 1; % m/s ---> 60 m/min
            
            % derived convective cooling parameters
            
            Prandl = dyn_visc_Air*c_spec_Air/spec_cond_Air;
            Reynolds = rho_Air*velocity_air*3/dyn_visc_Air;
            Nusselt = 0.332*Reynolds^(1/2)*Prandl^(1/3);
            alpha = Nusselt*spec_cond_Air/3;
            
            % start temperatures
            
            T(1) = this.toStores.FilterAlgaeReactor.aoPhases(1).fTemp; % this.oParent.toStores.Freshwater_Store.aoPhases.fTemp;%K  temperature of water in fresh water tank --> Boundary Condition
            T(2) = this.toStores.FilterAlgaeReactor.aoPhases(1).fTemp;%K  temperature of water/biomass in bioreactor
            T(3) = 273+20;%K  Environment Temperature --> Boundary Condition
            T(4) = 273+20;%K  Lamp Temperature
     
            
            % Node capacitances
             C=[V(end,1)*c_spec_H2O*rho_H2O,...
                V(end,2)*c_spec_H2O*rho_H2O,...
                V(end,3)*c_spec_Al*rho_Al,...
               V(end,4)*c_spec_Lamp*rho_Lamp];
            
           
            %% Thermal links
            
            % conductiv
            
            GL=1;  % W/K
            
            % radiative links
            
            GR(1) = 0.9 * A(2) * 0.8 * 1; % cylinder (without bottom) - 1 IR emmisivity is 0.8  --> emissvity of radiator * area of radiator * viewfactor between nodes * absorbtivity of receiver
            GR(2) = 0.9 * A(1) * 0.8 * 0.9;  % lamp to bioreactor
            GR(3) = 0.9 * A(1) * 0.2 * 0.9;  % lamp to environment
            %%%%%%%%%%%%%%%%%%%%%%%
            
            E=[0,0,0,0];
            
            
            this.fFlagTemp = 1;
            
        else
        end
        
        
        
        options = odeset('RelTol',1e-4,'AbsTol',[1e-3 1e-3 1e-3 1e-3],'MaxStep',1);
        
        if T(end,2)<273+20
            u = 0;
        else
            u = 1;
        end
        
        
        
        if T(end,2) < this.fT_soll
            
            if this.fPower < 850
                Q_heat = this.fPower;
            else
                Q_heat = 300;
            end
        elseif T(end,2) > thisfT_soll
            Q_heat = 0;
            
        end
        
        
        
        if this.oParent.fHarvest == 1
            Q_FW=this.fm*c_spec_H2O*(T(end,2)-T(end,1));
            this.fP_fill=this.fm*c_spec_H2O*7+this.fP_pump;
            
            this.fP_total = Q_FW + this.fP_fill;
        elseif this.oParent.fHarvest == 0
          
          
            Q_FW=0;
            
            this.fP_fill=0;
            this.fP_total = Q_FW + this.fP_fill;
        end
        
        if this.oParent.fHarvest == 1
            this.fP_harv=this.fP_pump;
        else
            this.fP_harv=0;
        end
        
        
        
        
     %   [time1,T_i1] = ode45(@Temps,[global_tick-1 global_tick],T(end,:),options);
     %   obj.time(global_tick+1)=time1(end);
     %   obj.T(global_tick+1,:)=T_i1(end,:);
     %   E(global_tick+1,:)=obj.C.*obj.T(global_tick+1,1:4);
     %   Q_punkt(global_tick+1,:)=[obj.GL(1)*(obj.T(end,3)-obj.T(end,2)),...  % heat through feet
     %       -obj.boltz*obj.GR(1)*(obj.T(end,2)^4-obj.T(end,3)^4),... % heat to environment through radiation
     %      -obj.u*obj.alpha*obj.A(1)*(obj.T(end,3)),...             % heat to environment through convection
     %      +obj.boltz*obj.GR(2)*(obj.T(end,4)^4-obj.T(end,2)^4),... % heat to bioreactor from lamps
     %      +obj.Q_heat,...                         % heat of bioreactor
     %      -obj.Q_FW];
     %   
        
        this.fQ_out=Q_heat+this.fP_harv+this.fP_fill;
     %   Q_environment=sum(Q_punkt(global_tick+1,1:3));
     %  TT = obj.T;
        fPower_New = this.fPower - this.fQ_out;
        
        this.oParent.toChildren.PowerControl.fPower = fPower_New;
        end
    end
end

       
      


%% Temp control
 %       function [dT] = Temps(obj,t,T)
 %           
 %                      
 %           dT = zeros(4,1);    % a column vector
 %           dT(1) = 0;
 %           
 %           
 %           dT(2) = (obj.GL(1)*(T(3)-T(2))...            % conduction
 %               - obj.boltz*obj.GR(1)*(T(2)^4-T(3)^4)...   % radiation
 %               + obj.boltz*obj.GR(2)*(T(4)^4-T(2)^4)...   % from lamps obj.GR mit sichtfaktor 0.6
 %               - obj.u*obj.alpha*obj.A(1)*(T(3))...               % convection (forced)
 %               + obj.Q_heat...
 %                - obj.Q_cool...
 %               - obj.Q_FW...
 %               )/obj.C(2);
 %           
 %           
 %           dT(3) = 0;
 %           if obj.Power<850
 %               dT(4)=0;
 %           else
 %               dT(4) = (- obj.boltz*obj.GR(2)*(T(4)^4-T(2)^4)...   % to bioreactor obj.GR mit sichtfaktor 0.8
 %                   - obj.boltz*obj.GR(3)*(T(4)^4-T(3)^4)...   % to environment obj.GR mit sichtfaktor 0.2
 %                   + 0.95*obj.Q_IR...                     % eigentliche Heizleistung Anteil aus Q el
 %                   )/obj.C(4);
 %           
 %            
 %      
 %   
    
      

        
            
    




            