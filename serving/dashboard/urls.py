from django.urls import path

from . import views

urlpatterns = [
    path('', views.freight_analysis, name='freight_analysis'),
]
