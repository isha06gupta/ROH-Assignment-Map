import pandas as pd
import numpy as np
import networkx as nx
import random
import matplotlib.pyplot as plt
import datetime
from datetime import timedelta
from pulp import *
import pandas as pd
import joblib
import networkx as nx
import numpy as np
G = joblib.load('ALL_INDIA_GRAPH_STATION.pkl')
G.edges(data=True)
tt = pd.read_csv('ETA_LOADED_ENSEMBLE.csv')
tt = tt.drop(columns={'Unnamed: 0'})
tts = tt.mean(axis=1)
ids = pd.read_csv('segments_lko.csv')
ids['tt']=tts
ids['SG']=ids['SEGMENT'].str.split('-')
df_wagon_due_roh=joblib.load("df_wagon_due_roh.pkl")
df_wagon_due_roh.head()
df_wagon_under_maint=joblib.load("df_wagon_under_maint.pkl")
df_wagon_due_roh=df_wagon_due_roh[~df_wagon_due_roh.wagon_no.isin(df_wagon_under_maint.wagon_no)]
df_wagon_due_roh['wagon_var']=df_wagon_due_roh['wagon_no']+'_'+df_wagon_due_roh['wagon_type']+'_'+df_wagon_due_roh['ravsttn']
df_wagon_on_loc=df_wagon_due_roh.groupby(["ravsttn","wagon_type"])['wagon_no'].count()
df_wagon_on_loc=df_wagon_on_loc.reset_index()
df_wagon_curr_holding=joblib.load("df_wagon_curr_holding.pkl")
df_depo_capacity=joblib.load("df_depo_capacity.pkl")
df_wagon_type=joblib.load("df_wagon_type.pkl")
df_wagon_depo=joblib.load("df_wagon_depo.pkl")
df_wagon_type_comb=df_wagon_depo.merge(df_wagon_type, how='cross')
df_wagon_comb_type_ava=joblib.load("df_wagon_comb_type_ava.pkl")
df_wagon_type_comb['workdepot_wagon_type']='('+df_wagon_type_comb['depot']+','+df_wagon_type_comb['wagon_type']+')'
df_wagon_type_comb['present'] = df_wagon_type_comb['workdepot_wagon_type'].isin(df_wagon_comb_type_ava['workdepot_wagon_type'])
df_wagon_type_comb["present"] = df_wagon_type_comb["present"].astype(int)
df_wagon_type_comb=df_wagon_type_comb.reset_index(drop=True)
df_wagon_type_comb.head()
wagon_handled=df_wagon_type_comb.groupby('depot')[['wagon_type','present',]].apply(lambda x: x.set_index('wagon_type').to_dict(orient='index')).to_dict()
vars=LpVariable.dicts("var",(df_wagon_due_roh['wagon_var'].values,df_wagon_type_comb['depot'].unique()),cat='Binary')
prob = LpProblem("Minimize wagon time to reach workdepot", LpMinimize)
wgn_workdepot = [(w, b) for w in  df_wagon_due_roh['wagon_var'].values for b in df_wagon_type_comb['depot'].unique()]
wgn_workdepot = [(w, b) for w in  df_wagon_due_roh['wagon_var'].values for b in df_wagon_type_comb['depot'].unique()]
df_final=pd.DataFrame()
for j in df_wagon_type_comb['depot'].unique():
    df=pd.DataFrame()
    wrk_shp_locn=j[:len(j)-2]
    cost=[]
    for i in df_wagon_due_roh['ravsttn'].unique():
        try:
            t=nx.shortest_path_length(G, source=i, target=wrk_shp_locn,weight='TRAVELTIME')
            print(t)
            cost.append(t)
        except:
            if(len(cost)==0):
                cost.append(0)
            else:
                cost.append(max(cost))
    df['ravsttn']=df_wagon_due_roh['ravsttn'].unique()
    df['cost']=pd.DataFrame(cost)
    df['workdepot']=j
    df_final=pd.concat(([df_final,df]))
df_cost=pd.merge(df_wagon_due_roh,df_final,how='inner')
df_cost=df_cost[['wagon_var','workdepot','cost']]
df_cost['cost'].replace(to_replace = 0, value = df_cost['cost'].mean(), inplace=True)
df = df_cost.groupby('wagon_var')[['workdepot','cost']].apply(lambda x: x.set_index('workdepot').to_dict(orient='index')).to_dict()
#costs=makeDict([df_wagon_due_roh['wagon_var'].values, df_wagon_type_comb['depot'].unique()], costs,0)
costs=df
prob += (
    lpSum([vars[w][b] * costs[w][b]['cost'] for (w, b) in wgn_workdepot]),
    "Sum_of_wagon_Transporting_Costs",)
Workdepot_capcity=df_depo_capacity.set_index('depot').to_dict('dict')
Workdepot_capcity=Workdepot_capcity['depot_capacity']
Current_wagon_load_wordepot=df_wagon_curr_holding.set_index('depot').to_dict()
Current_wagon_load_wordepot=Current_wagon_load_wordepot['current_holding']
for w in df_wagon_due_roh['wagon_var'].values:
    for b in df_wagon_type_comb['depot'].unique():
        prob+= (
            (vars[w][b]) <= 1,
            "Variable_can_be_either_zero_or_one"+str(vars[w][b])+"%s" % w,
    )
for b in df_wagon_type_comb['depot'].unique():
    try:
        prob += (
            lpSum([vars[w][b]  for w in df_wagon_due_roh['wagon_var'].values]) == max(Workdepot_capcity[b]-Current_wagon_load_wordepot[b],0),
            "Sum_of_wagons_assigned_should_be_less_than_capacity"+"%s" % b,)   
    except:
        prob += (
            lpSum([vars[w][b]  for w in df_wagon_due_roh['wagon_var'].values]) == max(Workdepot_capcity[b]-0,0),
            "Sum_of_wagons_assigned_should_be_less_than_capacity"+"%s" % b,) 
for w in df_wagon_due_roh['wagon_var'].values:
    df_wagon_type=df_wagon_due_roh[df_wagon_due_roh['wagon_var']==w]
    df_wagon_type=df_wagon_type.reset_index(drop=True)
    type=df_wagon_type['wagon_type'][0]
    for b in df_wagon_type_comb['depot'].unique():
        try:
            handled=wagon_handled[b][type]['present']
        except:
            handled=0
        try:
            prob+= (
            (vars[w][b]) <= handled,
            "wagon_handled_current_either_zero_or_one"+str(b)+"%s" % w,
    )
        except:
            prob+= (
            (vars[w][b]) <= handled,
            "wagon_handled_current_either_zero_or_one"+str(b)+"%s" % w,
    )
wagon_locn_dict=df_wagon_on_loc.groupby('ravsttn')[['wagon_type','wagon_no',]].apply(lambda x: x.set_index('wagon_type').to_dict(orient='index')).to_dict()
wagon_locn_dict   
location=df_wagon_on_loc['ravsttn'].unique()
for c in location:
    df_wagon_type=df_wagon_type[df_wagon_type['ravsttn']==c]
    for type in df_wagon_type['wagon_type'].unique():
        try:
            prob += (
            lpSum([vars[w][b]  for w in df_wagon_due_roh['wagon_var'].values if type in w if c in w for b in df_wagon_type_comb['depot'].unique()]) <= wagon_locn_dict[c][type]['wagon_no'],
            "Sum_of_wagons_assigned_should_be_less_than_capacity"+"%s" % c+type,
        )
        except:
            continue
print(prob.solve(),LpStatus[prob.status])