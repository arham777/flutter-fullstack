from django.urls import path
from .views import SignUpView, MealListCreateView, MealDetailView

urlpatterns = [
    path('signup/', SignUpView.as_view(), name='signup'),
    path('meals/', MealListCreateView.as_view(), name='meal-list-create'),
    path('meals/<int:pk>/', MealDetailView.as_view(), name='meal-detail'),
]