% calculate the max amount of CO2 at 1 atm and 298 K in BMIM Ac 
% based on H2O content in the IL

clear all
close all

xH2O = linspace(0,1,100);   % mol fraction
a = 11;     % water effect coefficient
b = 18;     % water effect coefficient
z = 1.84;   % mol CO2 / dm^3 IL (pure component capacity)
fMolarityCO2 = z./(1+b.*exp(a.*(xH2O-1)));  % mol CO2 / dm^3 IL
fMolarityCO2 = fMolarityCO2 .* 1000;        % mol CO2 / m^3 IL

M{1} = 0.19826;  % kg/mol
M{2} = 0.17021;  % kg/mol

figure(1)
plot(xH2O,fMolarityCO2)
xlabel('x_H_2_O - mol fraction H2O in IL')
ylabel('y_C_O_2 - concentration CO2 in IL (mol CO2/m^3 IL)')

clear z

%% Density value
afDensity{1} = [1054.0; 1054.0; 1039.7; 1027.1];    % [kg/m^3]
afDensity{2} = [1103.5; 1097.2; 1084.7; 1072.9];    % [kg/m^3]
%% CO2 content

% data from Yokozeki + Shiflet (2008) CO2 absorption in ILs
% Set min and max temperature values from the experimental dataset
fMinTemp = 283.1; % [K]
fMaxTemp = 348.1; % [K]
afTemperatureData = [283.1, 298.1, 323.1, 348.1];   % [K]
afTemperature = linspace(fMinTemp,fMaxTemp,100);    % [K]
% Check to see which IL is being used, BMIMAc or EMIMAc
% data from Shiflet and Yokozeki 2008 for BMIMAc ([C1C4Im][OAc])
% row 1 = 283.1 K, row 2 = 298.1 K, row 3 = 323.1 K, row 4 = 348.1 K
afPressureData{1} =    1000000.*[0.0102, 0.0502, 0.1002, 0.3997, 0.6994, 0,      0,      0,      0;...
                0.0101, 0.0502, 0.1003, 0.3999, 0.7002, 0.9996, 1.3001, 1.5001, 1.9994; ...
                0.0104, 0.0504, 0.1004, 0.3995, 0.7003, 1.0001, 1.3002, 1.4995, 1.9993; ...
                0.0104, 0.0505, 0.1000, 0.4002, 0.6994, 1.0003, 1.2994, 1.4997, 1.9993];

afSolubilityData{1} =  [0.192, 0.273, 0.307, 0.357, 0.394, 0, 0, 0, 0;...
                0.188, 0.252, 0.274, 0.324, 0.355, 0.381, 0.405, 0.420, 0.455;...
                0.108, 0.176, 0.204, 0.263, 0.292, 0.315, 0.334, 0.346, 0.373;...
                0.063, 0.129, 0.161, 0.226, 0.253, 0.272, 0.287, 0.294, 0.316];

% data from Shiflet and Yokozeki 2008 for EMIMAc ([C1C2Im][OAc])
% row 1 = 298.15
afPressureData{2} =    1000000.*[0.0100, 0.0499, 0.1000, 0.3996, 0.6995, 0.9996, 1,2998, 1.4997, 1.9998];

afSolubilityData{2} =  [0.189, 0.246, 0.267, 0.313, 0.340, 0.362, 0.384, 0.398, 0.428];

iCount = 0;
for ii = 1:2
    iCount = 1;
    for jj = 1:length(afSolubilityData{ii}(:,1))
        iCount = 1;
        for kk = 1:length(afSolubilityData{ii}(1,:))
            z{ii}(jj,kk) = afSolubilityData{ii}(jj,kk)./(1-afSolubilityData{ii}(jj,kk));%.* afDensity{ii}(jj) ./ M{ii};
            cafMolarityCO2{ii,jj}(iCount,:) = z{ii}(jj,kk)./(1+b.*exp(a.*(xH2O-1)));
            cafMolarityCO2{ii,jj}(iCount,:) = cafMolarityCO2{ii,jj}(iCount,:);
                if cafMolarityCO2{ii,jj}(iCount,1) == 0
                    cafMolarityCO2{ii,jj}(iCount,:) = [];
                    iCount = iCount - 1;
                end
            iCount = iCount + 1;
        end
    end  
end

for ii = 1:2
    if ii == 1
        figure(2)
        hold on
        ax = gca;
        % 255 = WHITE; 0 = BLACK; R - G - B
        colors1 = 1./255.*[0, 0, 255; 150, 150, 250; 150, 30, 70; 255, 0, 0];
        for jj = 1:length(afTemperatureData)
            for kk = 1:length(cafMolarityCO2{ii,jj}(:,1))
                plot(xH2O,cafMolarityCO2{ii,jj}(kk,:),'Color',colors1(jj,:))
            end
        end
        xlabel('x_H_2_O - mol fraction H2O in BMIM Ac')
        ylabel('y_C_O_2 - max. mol CO2 / mol BMIM Ac (mol CO2/mol IL)')
        hold off
    else
        figure(3)
        colors2 = 1./256.*[0, 0, 250; 245, 245, 245; 230, 230, 230; 180, 180 180; 130, 130, 130; 90, 90, 90; 60, 60, 60; 30, 30, 30; 0, 0, 0];
        hold on
        for jj = 1
            for kk = 1:length(cafMolarityCO2{ii,jj}(:,1))
                plot(xH2O,cafMolarityCO2{ii,jj}(kk,:),'Color',colors2(kk,:))
            end
        end
        xlabel('x_H_2_O - mol fraction H2O in EMIM Ac')
        ylabel('y_C_O_2 - max. mol CO2 / mol EMIM Ac (mol CO2/mol IL)')
        hold off
    end
end
