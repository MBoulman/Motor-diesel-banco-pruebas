%% PRÁCTICA 2 — ENSAYO DE MOTOR EN BANCO DE PRUEBAS
%  Motor Nissan YD — 4 cilindros diésel turbosobrealimentado
%  Código MATLAB
% =========================================================================

%% ── LECTURA DE DATOS DESDE EXCEL ────────────────────────────────────────
% El archivo Excel  tiene dos bloques de cabecera.
% La fila de nombres de columna (X_Value, Presión Salida Intercooler, ...)
% se encuentra en la fila 24 del Excel. Los datos empiezan en la fila 25.
%
% readtable salta automáticamente las filas anteriores con NumHeaderLines.

% Para archivos .xlsx hay que usar Range en lugar de NumHeaderLines.
% La fila 24 contiene los nombres de columna y los datos empiezan en la fila 25.
opts = spreadsheetImportOptions("NumVariables", 29);
opts.Sheet          = 1;
opts.DataRange      = "A25";          % datos desde fila 25
opts.VariableNamesRange = "A24";      % nombres de columna en fila 24
opts.VariableTypes  = repmat("double", 1, 29);
datos = readtable("Grupo 4 MT2026.xlsx", opts);

% Asignar nombres cortos
datos.Properties.VariableNames = { ...
    'X_Value', ...
    'P_sal_IC', ...          % Presión Salida Intercooler [bar manométrico]
    'P_ent_tur', ...         % Presión Entrada Turbina [bar]
    'T_amb', ...             % Temperatura Ambiente [°C]
    'T_aceite', ...          % Temperatura Aceite [°C]
    'T_agua_fren', ...       % Temperatura Agua Freno [°C]
    'T_ent_tur', ...         % Temperatura Entrada Turbina [°C]
    'T_sal_tur', ...         % Temperatura Salida Turbina [°C]
    'T_agua_ent', ...        % Temperatura Entrada Agua (motor) [°C]
    'T_agua_sal', ...        % Temperatura Salida Agua (motor) [°C]
    'T_ent_IC', ...          % Temperatura Entrada Intercooler [°C]
    'T_sal_IC', ...          % Temperatura Salida Intercooler [°C]
    'T_comb', ...            % Temperatura Combustible [°C]
    'P_sal_comp', ...        % Presión Salida Compresor [bar]
    'P_sal_tur', ...         % Presión Salida Turbina [bar]
    'Q_refr', ...            % Caudal Refrigerante [g/s]
    'n', ...                 % Régimen de Giro [rpm]
    'Q_comb_lh', ...         % Caudal Combustible [L/h]
    'ma_gs', ...             % Caudal Admisión / Gasto Aire [g/s]
    'T_hilo_V', ...          % Temperatura Hilo Admisión [V]
    'Me', ...                % Par [N·m]
    'n_cons', ...            % Régimen Consigna [rpm]
    'carga_pedal', ...       % Carga del Pedal [%]
    'ECU_x2', ...            % Entrada ECU x2 [V]
    'ECU', ...               % Entrada ECU [V]
    'n_TC', ...              % Régimen Turbocompresor [rpm]
    'T_cat', ...             % Temperatura Después Catalizador [°C]
    'p_amb', ...             % Presión Absoluta Ambiente [bar]
    'grado_carga' ...        % Grado de Carga [%]
};


%% ── CONSTANTES DEL MOTOR Y FLUIDOS ──────────────────────────────────────
Z        = 4;           % Número de cilindros
D        = 89e-3;       % Diámetro del cilindro [m]
S        = 100e-3;      % Carrera [m]
VT       = pi/4 * D^2 * S * Z;   % Cilindrada total [m³]

rho_gaso = 0.83e3;      % Densidad del gasóleo [kg/m³]  (= 0.83 kg/dm³)
Hc       = 43.2e6;      % Poder calorífico inferior del gasóleo [J/kg]
Fe       = 1/14.6;      % Dosado estequiométrico del gasóleo [-]
Ra       = 287;         % Constante específica del aire [J/(kg·K)]
cp_aire  = 1007;        % Cp del aire a ~25°C [J/(kg·K)]
cp_refr  = 3600;        % Cp del líquido refrigerante [J/(kg·K)]


%% ── EXTRACCIÓN DE VARIABLES MEDIDAS ─────────────────────────────────────

t           = datos.X_Value;        % Tiempo [s]
n           = datos.n;              % Régimen motor [rpm]
Me          = datos.Me;             % Par efectivo [N·m]
Q_comb_lh   = datos.Q_comb_lh;     % Caudal combustible [L/h]
ma_gs       = datos.ma_gs;         % Gasto másico de aire [g/s]
Q_refr_gs   = datos.Q_refr;        % Caudal refrigerante [g/s]

T_amb       = datos.T_amb;         % Temperatura ambiente [°C]
T_aceite    = datos.T_aceite;      % Temperatura aceite [°C]
T_agua_ent  = datos.T_agua_ent;    % Temperatura entrada agua motor [°C]
T_agua_sal  = datos.T_agua_sal;    % Temperatura salida agua motor [°C]
T_ent_ic    = datos.T_ent_IC;      % Temperatura entrada intercooler [°C]
T_sal_ic    = datos.T_sal_IC;      % Temperatura salida intercooler [°C]
T_sal_tur   = datos.T_sal_tur;     % Temperatura salida turbina [°C]
T_cat       = datos.T_cat;         % Temperatura después catalizador [°C]
T_agua_fren = datos.T_agua_fren;   % Temperatura agua freno dinamométrico [°C]

p_ic_man    = datos.P_sal_IC;      % Presión manométrica salida IC [bar]
p_amb       = datos.p_amb;         % Presión absoluta ambiente [bar]
n_TC        = datos.n_TC;          % Régimen turbocompresor [rpm]

% Presión absoluta a la salida del intercooler (entrada cilindros) [bar]
p_ic_abs    = p_ic_man + p_amb;


%% ── CÁLCULOS ─────────────────────────────────────────────────────────────

% — Potencia efectiva [kW] —
Pe = Me .* n * pi / 3e4;            % Me[N·m] · n[rpm] · 2π/60 / 1000

% — Gasto másico de combustible [kg/s] —
mf_kgs = rho_gaso * Q_comb_lh / (3600 * 1e3);   % L/h → m³/h → kg/h → kg/s
%         rho [kg/m³] * Q [L/h] * 1m³/1000L * 1h/3600s

% — Gasto másico de combustible [g/s] (útil para algunas fórmulas) —
mf_gs  = mf_kgs * 1e3;

% — Gasto másico de aire [kg/s] —
ma_kgs = ma_gs * 1e-3;

% — Gasto másico de gases de escape [kg/s] —

mgas_kgs = ma_kgs + mf_kgs;

% — Dosado relativo [-] —

Fr = (mf_gs ./ ma_gs) / Fe;         % mf [g/s] / ma [g/s] / Fe

% — Cp de los gases de escape [J/(kg·K)] — (ponderación másica estequiométrica)
cp_esc = 8.314e3/2 * (12*9 + 23/2*9 + 3.76*71/4./Fr*7 + 71/4*(1./Fr-1)*7) ...
                   ./ (12*44 + 23/2*18 + 3.76*71/4./Fr*28 + 71/4*(1./Fr-1)*32);

% — Densidad del aire tras el intercooler [kg/m³] —
rho_ref = (p_ic_abs * 1e5) ./ (Ra .* (T_sal_ic + 273.15));

% — Rendimiento volumétrico [-] —
eta_v = 2 * 60 * ma_kgs ./ (VT .* rho_ref .* n);

% — Consumo específico de combustible [g/(kW·h)] —
gef = mf_gs ./ Pe * 3600;           % [g/s / kW * 3600 s/h]

% — Rendimiento efectivo [-] —
eta_e = Pe ./ (mf_kgs * Hc * 1e-3); % Pe[kW] / (mf[kg/s] · Hc[kJ/kg])

% — Potencia calorífica del combustible [kW] —
Q_comb = mf_kgs * Hc * 1e-3;        % [kW]

% — Calor cedido al refrigerante [kW] —
%   Temperatura: salida del motor (más caliente) - entrada al motor (más fría)
Q_refr = (Q_refr_gs * 1e-3) .* cp_refr .* (T_agua_sal - T_agua_ent) * 1e-3;

% — Calor intercambiado en el intercooler [kW] —
Q_ic = ma_kgs .* cp_aire .* (T_ent_ic - T_sal_ic) * 1e-3;

% — Calor equivalente de los gases de escape [kW] —
Q_esc = mgas_kgs .* cp_esc .* (T_sal_tur - T_amb) * 1e-3;

% — Pérdidas no medidas: convección, radiación, aceite, comb. incompleta [kW] —
Q_resto = Q_comb - Pe - Q_refr - Q_ic - Q_esc;


%% ── CONFIGURACIÓN GLOBAL DE GRÁFICAS ────────────────────────────────────
% Ventana de suavizado: 100 puntos = 10 s con Δt=0.1 s
W = 100;

% Función de suavizado rápida (media móvil centrada)
sm = @(x) movmean(x, W);

% Función para exportar en alta resolución (300 dpi, formato PNG)
% Uso: guardar_fig(fig, 'nombre_archivo')
carpeta = 'Imagenes_Pract_2';
if ~exist(carpeta, 'dir'); mkdir(carpeta); end
guardar_fig = @(fig, nombre) exportgraphics(fig, ...
    fullfile(carpeta, [nombre '.png']), ...
    'Resolution', 300);


% Paleta de colores
C.azul    = [0.122 0.471 0.706];
C.rojo    = [0.839 0.153 0.157];
C.verde   = [0.173 0.627 0.173];
C.naranja = [1.000 0.498 0.055];
C.morado  = [0.580 0.404 0.741];
C.cian    = [0.090 0.745 0.812];
C.gris    = [0.5   0.5   0.5  ];


%% ═══════════════════════════════════════════════════════════════════════
%%  PARTE 1 — ESTABILIZACIÓN TÉRMICA
%% ═══════════════════════════════════════════════════════════════════════

% Fig 1 — Temperatura agua del freno
fig1 = figure(1); ax = axes(fig1);
plot(ax, t, sm(T_agua_fren), 'Color', C.rojo, 'LineWidth', 1.5)
title(ax, 'Temperatura del agua del freno dinamométrico')
xlabel(ax, 't (s)'); ylabel(ax, 'T (°C)'); grid(ax, 'on')
estilo_fig(fig1, ax)
guardar_fig(fig1, 'fig01_T_agua_freno')

% Fig 2 — Presión salida intercooler
fig2 = figure(2); ax = axes(fig2);
plot(ax, t, sm(p_ic_abs), 'Color', C.azul, 'LineWidth', 1.5)
title(ax, 'Presión absoluta a la salida del intercooler')
xlabel(ax, 't (s)'); ylabel(ax, 'p (bar)'); grid(ax, 'on')
estilo_fig(fig2, ax)
guardar_fig(fig2, 'fig02_P_intercooler')

% Fig 3 — Temperaturas de gas (catalizador y admisión)
fig3 = figure(3); ax = axes(fig3);
plot(ax, t, sm(T_cat),    'Color', C.rojo,  'LineWidth', 1.5); hold(ax,'on')
plot(ax, t, sm(T_sal_ic), 'Color', C.verde, 'LineWidth', 1.5)
legend(ax, 'T salida catalizador', 'T salida intercooler (admisión)', ...
       'Location', 'best')
xlabel(ax, 't (s)'); ylabel(ax, 'T (°C)'); grid(ax, 'on'); hold(ax,'off')
estilo_fig(fig3, ax)
guardar_fig(fig3, 'fig03_T_gases')

% Fig 4 — Régimen turbocompresor
fig4 = figure(4); ax = axes(fig4);
plot(ax, t, sm(n_TC), 'Color', C.naranja, 'LineWidth', 1.5)
title(ax, 'Régimen de giro del turbocompresor')
xlabel(ax, 't (s)'); ylabel(ax, 'n_{TC} (rpm)'); grid(ax, 'on')
estilo_fig(fig4, ax)
guardar_fig(fig4, 'fig04_n_TC')

% Fig 5 — Régimen motor
fig5 = figure(5); ax = axes(fig5);
plot(ax, t, sm(n), 'Color', C.azul, 'LineWidth', 1.5)
title(ax, 'Régimen de giro del motor')
xlabel(ax, 't (s)'); ylabel(ax, 'n (rpm)'); grid(ax, 'on')
estilo_fig(fig5, ax)
guardar_fig(fig5, 'fig05_n_motor')

% Fig 6 — Balance energético en el tiempo
fig6 = figure(6); ax = axes(fig6);
plot(ax, t, sm(Q_comb),  'Color', C.azul,    'LineWidth', 1.8); hold(ax,'on')
plot(ax, t, sm(Pe),      'Color', C.verde,   'LineWidth', 1.5)
plot(ax, t, sm(Q_refr),  'Color', C.rojo,    'LineWidth', 1.5)
plot(ax, t, sm(Q_ic),    'Color', C.naranja, 'LineWidth', 1.5)
plot(ax, t, sm(Q_esc),   'Color', C.cian,    'LineWidth', 1.5)
plot(ax, t, sm(Q_resto), 'Color', C.gris,    'LineWidth', 1.5, 'LineStyle', '--')
legend(ax, 'Q_{comb}', 'P_e', 'Q_{refrig}', 'Q_{intercooler}', ...
           'Q_{escape}', 'Q_{resto}', 'Location', 'northwest')
xlabel(ax, 't (s)'); ylabel(ax, 'Potencia (kW)')
title(ax, 'Balance energético en el tiempo')
grid(ax, 'on'); hold(ax,'off')
estilo_fig(fig6, ax)
guardar_fig(fig6, 'fig06_balance_temporal')

% Fig 7 — Caudal refrigerante
fig7 = figure(7); ax = axes(fig7);
plot(ax, t, sm(Q_refr_gs), 'Color', C.rojo, 'LineWidth', 1.5)
title(ax, 'Caudal de refrigerante')
xlabel(ax, 't (s)'); ylabel(ax, 'q_{refr} (g/s)'); grid(ax, 'on')
estilo_fig(fig7, ax)
guardar_fig(fig7, 'fig07_caudal_refrig')

% Fig 8 — Caudal combustible
fig8 = figure(8); ax = axes(fig8);
plot(ax, t, sm(Q_comb_lh), 'Color', C.naranja, 'LineWidth', 1.5)
title(ax, 'Caudal de combustible')
xlabel(ax, 't (s)'); ylabel(ax, 'Q_{comb} (L/h)'); grid(ax, 'on')
estilo_fig(fig8, ax)
guardar_fig(fig8, 'fig08_caudal_comb')

% Fig 9 — Temperaturas aceite y refrigerante
fig9 = figure(9); ax = axes(fig9);
plot(ax, t, sm(T_agua_sal), 'Color', C.rojo,   'LineWidth', 1.5); hold(ax,'on')
plot(ax, t, sm(T_agua_ent), 'Color', C.azul,   'LineWidth', 1.5)
plot(ax, t, sm(T_aceite),   'Color', C.naranja, 'LineWidth', 1.5)
legend(ax, 'T salida agua (motor)', 'T entrada agua (motor)', 'T aceite', ...
       'Location', 'best')
xlabel(ax, 't (s)'); ylabel(ax, 'T (°C)')
title(ax, 'Temperaturas del aceite y del refrigerante')
grid(ax, 'on'); hold(ax,'off')
estilo_fig(fig9, ax)
guardar_fig(fig9, 'fig09_T_aceite_refrig')

% Fig 10 — Calor intercooler
fig10 = figure(10); ax = axes(fig10);
plot(ax, t, sm(Q_ic), 'Color', C.morado, 'LineWidth', 1.5)
title(ax, 'Calor intercambiado en el intercooler')
xlabel(ax, 't (s)'); ylabel(ax, 'Q_{ic} (kW)'); grid(ax, 'on')
estilo_fig(fig10, ax)
guardar_fig(fig10, 'fig10_Q_intercooler')

% — Balance energético en régimen permanente (último punto) —
fprintf('\n=== Balance energético — régimen permanente (último punto) ===\n')
fprintf('  Q_comb        = %.2f kW (100.0%%)\n', Q_comb(end))
fprintf('  P_e           = %.2f kW (%.1f%%)\n',  Pe(end),      Pe(end)/Q_comb(end)*100)
fprintf('  Q_refr        = %.2f kW (%.1f%%)\n',  Q_refr(end),  Q_refr(end)/Q_comb(end)*100)
fprintf('  Q_intercooler = %.2f kW (%.1f%%)\n',  Q_ic(end),    Q_ic(end)/Q_comb(end)*100)
fprintf('  Q_escape      = %.2f kW (%.1f%%)\n',  Q_esc(end),   Q_esc(end)/Q_comb(end)*100)
fprintf('  Q_resto       = %.2f kW (%.1f%%)\n',  Q_resto(end), Q_resto(end)/Q_comb(end)*100)


%% ═══════════════════════════════════════════════════════════════════════
%%  PARTE 2 y 3 — PRESTACIONES Y PARÁMETROS DERIVADOS
%% ═══════════════════════════════════════════════════════════════════════

% Fig 11 — Par efectivo
fig11 = figure(11); ax = axes(fig11);
plot(ax, t, sm(Me), 'Color', C.rojo, 'LineWidth', 1.5)
title(ax, 'Par efectivo del motor')
xlabel(ax, 't (s)'); ylabel(ax, 'M_e (N·m)'); grid(ax, 'on')
estilo_fig(fig11, ax)
guardar_fig(fig11, 'fig11_par')

% Fig 12 — Potencia efectiva
fig12 = figure(12); ax = axes(fig12);
plot(ax, t, sm(Pe), 'Color', C.azul, 'LineWidth', 1.5)
title(ax, 'Potencia efectiva del motor')
xlabel(ax, 't (s)'); ylabel(ax, 'P_e (kW)'); grid(ax, 'on')
estilo_fig(fig12, ax)
guardar_fig(fig12, 'fig12_potencia')

% Fig 13 — Dosado relativo
fig13 = figure(13); ax = axes(fig13);
plot(ax, t, sm(Fr), 'Color', C.verde, 'LineWidth', 1.5)
title(ax, 'Dosado relativo')
xlabel(ax, 't (s)'); ylabel(ax, 'F_R (-)'); grid(ax, 'on')
ylim(ax, [0 1.5])
estilo_fig(fig13, ax)
guardar_fig(fig13, 'fig13_dosado')

% Fig 14 — Temperatura de escape
fig14 = figure(14); ax = axes(fig14);
plot(ax, t, sm(T_sal_tur), 'Color', C.rojo, 'LineWidth', 1.5)
title(ax, 'Temperatura de escape (salida turbina)')
xlabel(ax, 't (s)'); ylabel(ax, 'T_{esc} (°C)'); grid(ax, 'on')
estilo_fig(fig14, ax)
guardar_fig(fig14, 'fig14_T_escape')

% Fig 15 — Gasto másico de aire
fig15 = figure(15); ax = axes(fig15);
plot(ax, t, sm(ma_gs), 'Color', C.cian, 'LineWidth', 1.5)
title(ax, 'Gasto másico de aire')
xlabel(ax, 't (s)'); ylabel(ax, '$\dot{m}_a$ (g/s)', 'Interpreter', 'latex'); grid(ax, 'on')
estilo_fig(fig15, ax)
guardar_fig(fig15, 'fig15_gasto_aire')

% Fig 16 — Gasto másico de combustible
fig16 = figure(16); ax = axes(fig16);
plot(ax, t, sm(mf_gs), 'Color', C.naranja, 'LineWidth', 1.5)
title(ax, 'Gasto másico de combustible')
xlabel(ax, 't (s)'); ylabel(ax, '$\dot{m}_f$ (g/s)', 'Interpreter', 'latex'); grid(ax, 'on')
estilo_fig(fig16, ax)
guardar_fig(fig16, 'fig16_gasto_comb')

% Fig 17 — Consumo específico
fig17 = figure(17); ax = axes(fig17);
plot(ax, t, sm(gef), 'Color', C.morado, 'LineWidth', 1.5)
title(ax, 'Consumo específico de combustible')
xlabel(ax, 't (s)'); ylabel(ax, 'g_{ef} (g/(kW·h))'); grid(ax, 'on')
ylim(ax, [150 500])
estilo_fig(fig17, ax)
guardar_fig(fig17, 'fig17_consumo_especifico')

% Fig 18 — Rendimiento volumétrico
fig18 = figure(18); ax = axes(fig18);
plot(ax, t, sm(eta_v * 100), 'Color', C.azul, 'LineWidth', 1.5)
title(ax, 'Rendimiento volumétrico')
xlabel(ax, 't (s)'); ylabel(ax, '\eta_v (%)'); grid(ax, 'on')
ylim(ax, [50 110])
estilo_fig(fig18, ax)
guardar_fig(fig18, 'fig18_rdto_volumetrico')

% Fig 19 — Rendimiento efectivo
fig19 = figure(19); ax = axes(fig19);
plot(ax, t, sm(eta_e * 100), 'Color', C.verde, 'LineWidth', 1.5)
title(ax, 'Rendimiento efectivo')
xlabel(ax, 't (s)'); ylabel(ax, '\eta_e (%)'); grid(ax, 'on')
ylim(ax, [20 50])
estilo_fig(fig19, ax)
guardar_fig(fig19, 'fig19_rdto_efectivo')

%% ─────────────────────────────────────────────────────────────────────────
%%  Fig 20 — Diagrama circular de reparto de potencia (régimen permanente)
%% ─────────────────────────────────────────────────────────────────────────
% Se usa el promedio de los últimos 30 s del ensayo como "régimen permanente"
% (equivalente a los últimos 300 puntos con Δt = 0.1 s).

N_fin = 300;
idx   = max(1, length(t)-N_fin+1) : length(t);   % índices del intervalo final

val_Pe    = mean(Pe(idx),      'omitnan');
val_refr  = mean(Q_refr(idx),  'omitnan');
val_ic    = mean(Q_ic(idx),    'omitnan');
val_esc   = mean(Q_esc(idx),   'omitnan');
val_resto = mean(Q_resto(idx), 'omitnan');
val_comb  = mean(Q_comb(idx),  'omitnan');

% Porcentajes respecto a Q_comb
vals = [val_Pe, val_refr, val_ic, val_esc, val_resto];
pcts = vals / val_comb * 100;

% Etiquetas con nombre, kW y porcentaje
etiquetas = { ...
    sprintf('Potencia efectiva\n%.1f kW  (%.1f%%)',    val_Pe,    pcts(1)), ...
    sprintf('Refrigerante motor\n%.1f kW  (%.1f%%)',   val_refr,  pcts(2)), ...
    sprintf('Intercooler\n%.1f kW  (%.1f%%)',          val_ic,    pcts(3)), ...
    sprintf('Gases de escape\n%.1f kW  (%.1f%%)',      val_esc,   pcts(4)), ...
    sprintf('Pérdidas no medidas\n%.1f kW  (%.1f%%)',  val_resto, pcts(5))  ...
};

% Colores coherentes con el balance temporal (fig 6)
colores_pie = [C.verde; C.rojo; C.naranja; C.cian; C.gris];


fig20 = figure(20);
fig20.Units    = 'centimeters';
fig20.Position = [5 5 18 14];

ax20 = axes(fig20);
p = pie(ax20, pcts, etiquetas);


title(ax20, sprintf('Reparto de potencia — régimen permanente\nQ_{comb} = %.1f kW  (promedio últimos %.0f s)', ...
      val_comb, N_fin*0.1), ...
      'FontSize', 11, 'FontName', 'Arial', 'FontWeight', 'bold')

guardar_fig(fig20, 'fig20_reparto_potencia')

fprintf('\n Las 20 figuras se han guardado en la carpeta "%s" a 300 dpi.\n', carpeta)


%% ── FUNCIONES LOCALES ───────────────────────────────────────────────────
% Estilo base aplicado a todas las figuras
function estilo_fig(fig, ax)
    fig.Units  = 'centimeters';
    fig.Position(3:4) = [16 10];    % 16 × 10 cm (tamaño A4 en columna)
    set(ax, 'FontName', 'Arial', 'FontSize', 10, ...
            'LineWidth', 0.8, 'Box', 'on', ...
            'GridAlpha', 0.3, 'GridLineStyle', '--')
end
