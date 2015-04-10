% function [TCB_out,TEB_out,O2_exchange,CO2_exchange,water_exchange]=plant_model(PPF,CO2,RH,p_atm,H,time)
function [this,INEDIBLE_CGR_d_out,INEDIBLE_CGR_f_out,ED_CGR_d_out,ED_CGR_f_out,O2_exchange,CO2_exchange,water_exchange,WaterOverall,WaterNeed,Act_Out]=plant_model(this, time,p_atm,RH,Inlet_Water,TimeAvailability,CO2)

% O2_exchange=0;
% CO2_exchange=0;
% water_exchange=0;


% CO2=t;
PPF=this.state.PPF;
WaterOverall=0;
WaterInPlant=0;
WaterNeed=0;
ED_CGR = 0;
INEDIBLE_CGR_d = 0;
INEDIBLE_CGR_f = 0;
ED_CGR_d = 0;
ED_CGR_f = 0;
Act_Out = 0;
%this.time_constant=15;
INEDIBLE_CGR_d_out = 0;
INEDIBLE_CGR_f_out = 0;
ED_CGR_d_out =  0;
ED_CGR_f_out = 0;

% Check 4 if Astronauts have Time 4 harvesting
% if this.state.newgeneration~=0 && this.state.internalGeneration <= this.state.newgeneration && NeedTime4Activity==1
%
%     this.state.emerg_time=time+this.state.InitEmerg_time+((3/24)*this.state.extension*this.time_constant);
% end
% this.state.emerg_time

if time <= this.state.emerg_time && time > ((this.state.emerg_time) - (2*this.state.extension*this.time_fact))
    if TimeAvailability==0
        %         time
        this.state.emerg_time = this.state.emerg_time + 1;
        disp('Versp?tung beim Pflanzen /n');
    end
end

if this.state.internaltime >= this.state.harv_time - 1 && this.state.internaltime < ((this.state.harv_time - 1) + (1*this.state.extension*this.time_fact))
    if TimeAvailability==0
        %         time
        this.state.harv_time = this.state.harv_time + 1;
        disp('Versp?tung beim Ernten /n');
    end
end


if time < 3
    Act_Out = {'Planting',(1*this.time_constant),(2/24)*this.state.extension*this.time_constant};
    %disp('Planting');
    if this.state.internaltime == (this.state.harv_time - (2*this.time_constant))
        Act_Out = {'Harvest',(2*this.time_constant),(1/24)*this.state.extension*this.time_constant};
    end
else
    if time == (this.state.emerg_time - (2*this.time_constant))
        Act_Out = {'Planting',(2*this.time_constant),(2/24)*this.state.extension*this.time_constant};
        disp('Planting2');
    end
    if this.state.internaltime == (this.state.harv_time - (2*this.time_constant))
        Act_Out = {'Harvest',(2*this.time_constant),(1/24)*this.state.extension*this.time_constant};
    end
end

% time
% Act_Out
% pause(0.1);
% condition: plant is alive?
if time>10%this.state.emerg_time
    %disp('Time > 10');
    if this.state.internaltime<this.state.harv_time && CO2 > 350 && CO2 < 1400
        %         if this.state.internalGeneration <= this.state.newgeneration
        %disp('In If drinnen');
        this.state.internaltime=this.state.internaltime+3;%eigntl +1
        % tA:time after emergence [UOT]
        tA=[1/CO2 1 CO2 CO2^2 CO2^3]*this.plant.matrix_tA*[1/PPF; 1; PPF; PPF^2; PPF^3]*this.time_constant;
        Det_Dry_Phase = this.state.CQY;
        [this, DOP,CGR,DTR] = lib.components.PlantModule.plant_equations(this, this.state.internaltime,tA,this.plant.tQ,this.plant.tM_nominal,PPF,CO2,RH,p_atm,this.state.H);
        Det_Dry_Phase = Det_Dry_Phase - this.state.CQY;
        TCB_check=this.state.TCB+CGR*this.state.extension;
        % TCB: total crop biomass, on a dry basis [g/m?]
        
        % water_exchange: water vapor transpired from the plant [L/m≤/(UOT)]
        this.state.water_exchange=DTR*this.state.extension;
        if this.state.internaltime < this.plant.tE
            WaterInPlant = 9 * TCB_check/1000;
        else
            H20InPlant_fct = interp1([this.plant.tE this.plant.tM_nominal], [9 0],this.state.internaltime,'linear');
            WaterInPlant = H20InPlant_fct * TCB_check/1000;
        end
        % Fresh basis water content
        switch this.plant.name
            case 'Drybean'
                FBWC = 1/9;
            case 'Lettuce'
                FBWC = 95/5;
            case 'Peanut'
                FBWC = 5.6/94.4;
            case 'Rice'
                FBWC = 12/88;
            case 'Soybean'
                FBWC = 10/90;
            case 'Sweetpotato'
                FBWC = 71/29;
            case 'Tomato'
                FBWC = 94/6;
            case 'Wheat'
                FBWC = 12/88;
            case 'Whitepotato'
                FBWC = 80/20;
        end
        %         this.state.water_exchange
        if this.state.internaltime>this.plant.tE
            WaterNeed = (9 * (CGR * this.state.extension)/1000)...
                + this.state.water_exchange + ((FBWC*this.plant.XFRT*CGR*this.state.extension)/1000);
        else
            WaterNeed = (9 * (CGR * this.state.extension)/1000) + this.state.water_exchange;
        end
        WaterOverall = WaterInPlant + this.state.water_exchange;
        
        if (Inlet_Water > WaterNeed) && this.state.t_without_H2O <=this.time_constant
            
            this.state.TCB = this.state.TCB+CGR*this.state.extension;
            %disp('Enough Water');
            % TEB: total edible biomass, on a dry basis [g/m≤]
            if this.state.internaltime>this.plant.tE
                 %disp('Enough Water and internal time');
                this.state.TEB=this.state.TEB+this.plant.XFRT*CGR*this.state.extension;
                this.ED_CGR_d = this.ED_CGR_d + (this.plant.XFRT*CGR*this.state.extension);
                this.ED_CGR_f = this.ED_CGR_f +(this.plant.XFRT*CGR*this.state.extension) + (FBWC*this.plant.XFRT*CGR*this.state.extension);
                
            else
                %disp('ed_cgr_d=0');
                this.state.TEB=this.state.TEB;
                ED_CGR_d = 0;
                ED_CGR_f = 0;
            end
            this.INEDIBLE_CGR_d = this.INEDIBLE_CGR_d + (CGR * this.state.extension);
            this.INEDIBLE_CGR_f = this.INEDIBLE_CGR_f + (9 * (CGR * this.state.extension)) + (CGR * this.state.extension);
            % O2_exchange: O2 provided to the environment [g/m≤/(UOT)]
            this.state.O2_exchange=DOP*this.state.extension;
            
            
            % CO2_exchange: CO2 subtracted to the environment [g/m≤/(UOT)]
            this.state.CO2_exchange=DOP*44/32*this.state.extension*this.state.CO2_assimilation_fct;
            
            
        else
            disp('Not Enough Water');
            %             %disp('Not enough Water!! In plant_model line 147');
            this.state.t_without_H2O = this.state.t_without_H2O + 1;
            if  this.state.t_without_H2O == 1
                this.state.TCB_constant = this.state.TCB;
                this.state.TEB_constant = this.state.TEB;
            end
            if this.state.t_without_H2O <=4*this.time_constant;
                Without_H2O_fct = 1 - (this.state.t_without_H2O/(this.time_constant*4));
                if Inlet_Water - (WaterNeed * Without_H2O_fct) <=0
                    Without_H2O_fct = 0;
                end
            else
                Without_H2O_fct = 0;
            end
            WaterNeed = WaterNeed * Without_H2O_fct;
            this.state.A=this.state.A * Without_H2O_fct;
            this.state.CUE_24 = this.state.CUE_24 * Without_H2O_fct;
            this.state.TCB=this.state.TCB_constant + (CGR * Without_H2O_fct*this.state.extension);
            this.state.TEB=this.state.TEB_constant + (CGR* Without_H2O_fct*this.state.extension);
            this.state.O2_exchange=this.state.O2_exchange * Without_H2O_fct;
            this.state.CO2_exchange=this.state.CO2_exchange * Without_H2O_fct;
            this.state.water_exchange=this.state.water_exchange* Without_H2O_fct;
            WaterInPlant = 9 * this.state.TCB;
            WaterOverall = WaterInPlant + this.state.water_exchange;
            this.state.P_net=this.state.P_net * Without_H2O_fct;
            this.state.CGR=this.state.CGR * Without_H2O_fct;
            this.state.CQY=this.state.CQY * Without_H2O_fct;
        end
        
        
    else
        disp('wo bin ich');
        if CO2 > 1400
             disp('Warning: CO2ppm > 1400 /n, plant_model line 164');
        end
        if this.state.internaltime<this.state.harv_time && CO2 < 350
             disp('Warning: CO2ppm < 350 /n, plant_model line 183');
            this.state.O2_exchange=0;
            this.state.CO2_exchange=0;
            this.state.water_exchange=0;
        else
            disp('go for it');
            Act_Out = 1;
            this.state.A=0;
            this.state.CUE_24 = 0;
            this.state.TCB=0;
            this.state.TEB=0;
            this.state.O2_exchange=0;
            this.state.CO2_exchange=0;
            this.state.water_exchange=0;
            this.state.internaltime=0;
            this.state.P_net=0;
            this.state.CGR=0;
            this.state.CQY=0;
            this.state.t_without_H2O = 0;
            this.state.AddGen = 1;
            INEDIBLE_CGR_d_out = this.INEDIBLE_CGR_d;
            INEDIBLE_CGR_f_out = this.INEDIBLE_CGR_f;
            ED_CGR_d_out = this.ED_CGR_d;
            ED_CGR_f_out = this.ED_CGR_f;
            
            this.INEDIBLE_CGR_d = 0;
            this.INEDIBLE_CGR_f = 0;
            this.ED_CGR_d = 0;
            this.ED_CGR_f = 0;
            %         if this.state.AddGen
            %             this.state.internalGeneration=this.state.internalGeneration + 1;
            %             this.state.AddGen = 0;
            %         end
            this.state.newgeneration = this.state.newgeneration + 1;
            if this.state.newgeneration~=0 && this.state.internalGeneration <= this.state.newgeneration
                
                this.state.emerg_time=time+this.state.InitEmerg_time+((1/24)*this.state.extension*this.time_constant);% + 1hr/m2 for harvesting time
                %         elseif this.state.newgeneration~=0 && this.state.internalGeneration <= this.state.newgeneration && NeedTime==0
                %             this.state.emerg_time=time+this.state.InitEmerg_time+((1/24)*this.state.extension*this.time_constant);% + 1hr/m2 for harvesting time
            else
                %         else
                this.state.emerg_time=inf;
            end
            
        end
    end
    %     end
    
end
CGR=this.state.CGR*this.time_constant*this.state.extension;
P_net=this.state.P_net;
A=this.state.A;
CUE_24=this.state.CUE_24;
O2_exchange=this.state.O2_exchange;

% ######################################################
%CO2 CORRELATION (PLEASE SET CORRELATION FACTORS IN plant_equation to 1 to)

if 1
    CORR_CO2_fct = [0.642/0.992 0.121/0.18 1.051/1.439 0.486/0.7 0.456/0.726 0.52/0.78 0.467/0.688 0.464/0.714 1];
    
    CO2_exchange=this.state.CO2_exchange*44*CORR_CO2_fct(this.state.plant_type)/32;
else
    CO2_exchange=this.state.CO2_exchange*44/32;
end



% ########################################################


water_exchange=this.state.water_exchange;
TCB_out=this.state.TCB;
TEB_out=this.state.TEB;
CQY=this.state.CQY;
